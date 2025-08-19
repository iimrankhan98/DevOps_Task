
# Terraform: EC2 + ALB + ASG + RDS + SSM + Secrets (Rotation 7d) + KMS + CloudFront + GitHub Actions

This repository provisions:
- A VPC with public subnets (EC2/ALB) and private subnets (RDS).
- Application Load Balancer fronting an Auto Scaling Group of EC2 instances.
- User data installs **Apache (httpd)** and **PHP**, serving a basic `index.php`.
- RDS (MySQL) with credentials stored in **AWS Secrets Manager** encrypted by a **KMS CMK**.
- Automatic **secret rotation every 7 days** using AWS's official **RDS MySQL Single-User** rotation Lambda from the **Serverless Application Repository**.
- **AWS Systems Manager Session Manager** enabled on EC2 via IAM role.
- Optional **CloudFront** distribution in front of the ALB.
- A **GitHub Actions** workflow for Terraform checks (fmt/validate/plan) and code quality (tflint, tfsec).

> Region defaults to **us-east-1**. Adjust in `variables.tf` if needed.

## Prerequisites
- Terraform >= 1.5
- An AWS account and credentials with permissions to create the above resources.
- (Optional) TFLint and tfsec locally if you run tools outside GitHub Actions.

## Quick Start

```bash
terraform init
terraform apply -auto-approve
```

After `apply`, check outputs:
- `alb_dns_name` – visit `http://<alb_dns>` to hit Apache/PHP (or use CloudFront if enabled).
- `cloudfront_domain_name` – access via HTTPS through CloudFront (if enabled).
- `rds_endpoint` – endpoint for your app to connect to MySQL.
- `db_secret_arn` – the ARN of the Secrets Manager secret that stores DB creds.

> Note: For demo simplicity, EC2 instances run in **public subnets** behind a public ALB; RDS runs in **private subnets** (not publicly accessible). Security groups restrict DB access to the ASG only.

## Important Notes on Rotation & KMS
- **KMS key** (`aws_kms_key.secrets_key`) encrypts the secret; native KMS key rotation is **annual** (enabled here). The `key_rotation_days` variable is just documented metadata.
- **7-day rotation** is implemented via `aws_secretsmanager_secret_rotation` and the AWS-provided SAR app `SecretsManagerRDSMySQLRotationSingleUser`. The Lambda runs inside the VPC (private subnets).

## GitHub Actions
A workflow is included at `.github/workflows/terraform.yml`:
- On PRs: fmt, validate, tflint, tfsec, and a Terraform plan.
- On push to `main`: same checks plus plan output.

Set these repository secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (optional; defaults to us-east-1)

## Clean Up
```bash
terraform destroy -auto-approve
```

## Variables
See `variables.tf` for all variables and their defaults.

## Outputs
See `outputs.tf` for the exported values.

## Session Manager
Instances have the `AmazonSSMManagedInstanceCore` policy attached via an instance profile, so you can open a console session from the AWS Systems Manager console without SSH.

## Caveats
- This is a reference environment. For production, consider:
  - Private subnets for ASG + NAT Gateway for patching.
  - HTTPS on ALB with ACM certificates and CloudFront custom domain.
  - WAF in front of ALB/CloudFront.
  - More restrictive SG rules and least-privilege IAM.
