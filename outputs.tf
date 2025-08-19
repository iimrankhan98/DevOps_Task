output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.alb_cdn.domain_name
}

output "rds_endpoint" {
  value = aws_db_instance.app_db.address
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}

output "kms_key_id" {
  value = aws_kms_key.db_key.key_id
}
