output "rds_endpoint" {
  value = aws_db_instance.this.address
}

output "rds_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = local.db_name
}

output "rds_master_user_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "master_key_secret_arn" {
  value = aws_secretsmanager_secret.master_key.arn
}

output "salt_key_secret_arn" {
  value = aws_secretsmanager_secret.salt_key.arn
}

output "s3_log_bucket_name" {
  value = aws_s3_bucket.log.bucket
}

output "s3_log_bucket_arn" {
  value = aws_s3_bucket.log.arn
}

output "log_group_name_app" {
  value = aws_cloudwatch_log_group.app.name
}
