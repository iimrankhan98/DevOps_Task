
locals {
  name = var.project_name
  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

# ---------------- VPC & Networking ----------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

# Public subnets + route
resource "aws_subnet" "public" {
  for_each = {
    a = var.public_subnet_cidrs[0]
    b = var.public_subnet_cidrs[1]
  }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[ index(keys(each.value == var.public_subnet_cidrs[0] ? {a=1} : {b=1}), 0) ]
  tags = merge(local.tags, { Name = "${local.name}-public-${each.key}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private subnets (for RDS)
resource "aws_subnet" "private" {
  for_each = {
    a = var.private_subnet_cidrs[0]
    b = var.private_subnet_cidrs[1]
  }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[ index(keys(each.value == var.private_subnet_cidrs[0] ? {a=1} : {b=1}), 0) ]
  tags = merge(local.tags, { Name = "${local.name}-private-${each.key}" })
}

resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-db-subnets"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = merge(local.tags, { Name = "${local.name}-db-subnets" })
}

# ---------------- Security Groups ----------------
resource "aws_security_group" "alb_sg" {
  name        = "${local.name}-alb-sg"
  description = "Allow HTTP from the world"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-alb-sg" })
}

resource "aws_security_group" "asg_sg" {
  name        = "${local.name}-asg-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-asg-sg" })
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.name}-rds-sg"
  description = "Allow MySQL from ASG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ASG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.asg_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-rds-sg" })
}

# ---------------- IAM for Session Manager ----------------
resource "aws_iam_role" "ec2_role" {
  name               = "${local.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ---------------- KMS for Secrets ----------------
resource "aws_kms_key" "secrets_key" {
  description             = "KMS CMK for Secrets Manager"
  enable_key_rotation     = true # native annual rotation
  deletion_window_in_days = 10
  tags = merge(local.tags, { Name = "${local.name}-kms-secrets" })
}

resource "aws_kms_alias" "secrets_alias" {
  name          = "alias/${local.name}-secrets"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# ---------------- Secrets Manager (DB creds) with rotation every 7 days ----------------
resource "random_password" "db" {
  length  = 20
  special = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name}/db/master"
  description = "Master credentials for RDS"
  kms_key_id  = aws_kms_key.secrets_key.arn
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials_value" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({ username = var.db_username, password = random_password.db.result })
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotation_app" {
  name             = "${local.name}-rds-rotation"
  application_id   = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"
  semantic_version = "1.1.307"

  parameters = {
    functionName       = "${local.name}-rds-rotation-fn"
    vpcSubnetIds       = join(",", [for s in aws_subnet.private : s.id])
    vpcSecurityGroupIds = aws_security_group.rds_sg.id
  }
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotation_app.outputs["FunctionArn"]

  rotation_rules {
    automatically_after_days = 7
  }

  depends_on = [aws_secretsmanager_secret_version.db_credentials_value]
}

# ---------------- RDS ----------------
resource "aws_db_instance" "app_db" {
  identifier              = "${local.name}-db"
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  db_name                 = var.db_name
  username                = var.db_username
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  allocated_storage       = 20
  max_allocated_storage   = 100
  multi_az                = false
  storage_type            = "gp3"
  skip_final_snapshot     = true
  publicly_accessible     = false
  deletion_protection     = false
  apply_immediately       = true
  backup_retention_period = 1

  tags = merge(local.tags, { Name = "${local.name}-db" })
}

# ---------------- ALB + Target Group + ASG ----------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

resource "aws_lb" "app_alb" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = merge(local.tags, { Name = "${local.name}-alb" })
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${local.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  tags = merge(local.tags, { Name = "${local.name}-tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  user_data = base64encode(file("${path.module}/user_data.sh"))

  network_interfaces {
    security_groups = [aws_security_group.asg_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.name}-ec2" })
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${local.name}-asg"
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]
  health_check_type = "EC2"

  tag {
    key                 = "Name"
    value               = "${local.name}-ec2"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------- CloudFront (origin = ALB) ----------------
resource "aws_cloudfront_distribution" "alb_cdn" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name = aws_lb.app_alb.dns_name
    origin_id   = "alb-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.name} CloudFront -> ALB"
  default_root_object = "index.php"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 10
    max_ttl                = 30
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.tags
}
