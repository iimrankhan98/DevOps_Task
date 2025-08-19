# Terraform AWS Infrastructure

This project provisions AWS infrastructure using Terraform.  
It includes networking, compute, database, security, load balancing, and CDN resources.

---

## 🚀 Architecture Diagram

```
                       +-----------------------+
                       |   CloudFront (CDN)    |
                       |  dxxx.cloudfront.net  |
                       +-----------+-----------+
                                   |
                                   v
                       +-----------------------+
                       |  Application Load     |
                       |    Balancer (ALB)     |
                       |  app-alb DNS Name     |
                       +-----------+-----------+
                                   |
                     +-------------+-------------+
                     |                           |
             +-------v-------+           +-------v-------+
             |   EC2 (App)   |           |   EC2 (App)   |
             |  Apache + PHP |           |  Apache + PHP |
             +---------------+           +---------------+
                     |                           |
                     +-------------+-------------+
                                   |
                                   v
                         +-------------------+
                         |   RDS (MySQL)     |
                         |  appdb Database   |
                         | rds_endpoint addr |
                         +-------------------+
```

---

## 🚀 Resources Created

### Networking
- **VPC** (`aws_vpc.main`)
- **Public Subnets** (`aws_subnet.public` – 2 across availability zones)
- **Internet Gateway** (`aws_internet_gateway.igw`)
- **Route Table & Association** (`aws_route_table.public`, `aws_route_table_association.public`)

### Security
- **Security Group** (`aws_security_group.app_sg`)  
  - Allows HTTP (80) and SSH (22) from anywhere  
  - Allows all outbound traffic  

### Compute
- **Launch Template** (`aws_launch_template.app`)  
  - Based on latest Ubuntu 20.04 AMI  
  - Installs Apache + PHP  
  - Deploys a simple PHP page (`hello word`)  

- **Auto Scaling Group** (`aws_autoscaling_group.app_asg`)  
  - Desired capacity: 2  
  - Min size: 1  
  - Max size: 3  
  - Attached to public subnets and ALB Target Group  

### Load Balancing
- **Application Load Balancer** (`aws_lb.app_alb`)  
- **Target Group** (`aws_lb_target_group.app_tg`)  
- **Listener** (`aws_lb_listener.app_listener`)  

### Database
- **Random Password** (`random_password.db`)  
- **KMS Key** (`aws_kms_key.db_key`)  
- **Secrets Manager Secret** (`aws_secretsmanager_secret.db_secret`)  
- **Secrets Manager Version** (`aws_secretsmanager_secret_version.db_secret_version`)  
- **RDS Instance** (`aws_db_instance.app_db`)  
  - MySQL 8.0.42  
  - Instance class: `db.m7g.large`  
  - DB name: `appdb`  
  - Credentials stored in Secrets Manager  
- **DB Subnet Group** (`aws_db_subnet_group.db_subnets`)  

### CDN
- **CloudFront Distribution** (`aws_cloudfront_distribution.alb_cdn`)  
  - Origin: Application Load Balancer  
  - Viewer Protocol Policy: Redirect HTTP → HTTPS  
  - Default CloudFront certificate  

---

## 📤 Outputs

- **ALB DNS Name**  
  ```hcl
  output "alb_dns_name" {
    value = aws_lb.app_alb.dns_name
  }
  ```

- **CloudFront Domain Name**  
  ```hcl
  output "cloudfront_domain_name" {
    value = aws_cloudfront_distribution.alb_cdn.domain_name
  }
  ```

- **RDS Endpoint**  
  ```hcl
  output "rds_endpoint" {
    value = aws_db_instance.app_db.address
  }
  ```

- **DB Secret ARN**  
  ```hcl
  output "db_secret_arn" {
    value = aws_secretsmanager_secret.db_secret.arn
  }
  ```

- **KMS Key ID**  
  ```hcl
  output "kms_key_id" {
    value = aws_kms_key.db_key.key_id
  }
  ```

---

## 🔧 Usage

1. Initialize Terraform
   ```bash
   terraform init
   ```

2. Preview the changes
   ```bash
   terraform plan
   ```

3. Apply the configuration
   ```bash
   terraform apply -auto-approve
   ```

4. Destroy resources when not needed
   ```bash
   terraform destroy -auto-approve
   ```

---
