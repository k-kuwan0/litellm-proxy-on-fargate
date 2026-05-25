variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "master_key_secret_arn" {
  type = string
}

variable "salt_key_secret_arn" {
  type = string
}

variable "s3_log_bucket_arn" {
  type = string
}

variable "rds_resource_id" {
  type        = string
  description = "RDS DB instance resource ID (dbi-...). Used in rds-db:connect IAM resource ARN."
}

variable "db_app_username" {
  type        = string
  description = "PostgreSQL user name that the ECS task connects as via IAM token auth."
}
