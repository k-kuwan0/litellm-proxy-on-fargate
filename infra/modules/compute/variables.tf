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

variable "rds_master_user_secret_arn" {
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
