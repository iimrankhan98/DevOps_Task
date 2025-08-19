
variable "project_name" {
  description = "A short name used to tag and name resources"
  type        = string
  default     = "devops-demo"
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs (two AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs (two AZs)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for ASG"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

variable "db_engine" {
  description = "RDS engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username (will be stored in Secrets Manager too)"
  type        = string
  default     = "adminuser"
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach the ALB on 80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cloudfront" {
  description = "Whether to create a CloudFront distribution fronting the ALB"
  type        = bool
  default     = true
}

variable "key_rotation_days" {
  description = "KMS CMK rotation period in days (note: AWS KMS native rotation is annual; used here as a tag and doc)"
  type        = number
  default     = 7
}
