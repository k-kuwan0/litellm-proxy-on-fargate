variable "project_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "bastion_security_group_id" {
  type = string
}

variable "rds_master_user_secret_arn" {
  type        = string
  description = "ARN of the RDS managed master user secret. bastion can read it for DB bootstrap / break-glass."
}
