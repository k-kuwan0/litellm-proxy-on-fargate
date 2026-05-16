output "aws_region" {
  value = local.aws_region
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "private_subnet_id_a" {
  value = module.network.private_subnet_ids[0]
}

output "private_subnet_id_c" {
  value = module.network.private_subnet_ids[1]
}

output "service_security_group_id" {
  value = module.network.service_security_group_id
}

output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}

output "ecs_cluster_arn" {
  value = module.compute.ecs_cluster_arn
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}

output "ecr_repository_name" {
  value = module.compute.ecr_repository_name
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "target_group_arn" {
  value = module.compute.target_group_arn
}

output "execution_role_arn" {
  value = module.compute.execution_role_arn
}

output "task_role_arn" {
  value = module.compute.task_role_arn
}

output "log_group_name_app" {
  value = module.data.log_group_name_app
}

output "rds_endpoint" {
  value = module.data.rds_endpoint
}

output "rds_port" {
  value = module.data.rds_port
}

output "db_name" {
  value = module.data.db_name
}

output "rds_master_user_secret_arn" {
  value = module.data.rds_master_user_secret_arn
}

output "master_key_secret_arn" {
  value = module.data.master_key_secret_arn
}

output "salt_key_secret_arn" {
  value = module.data.salt_key_secret_arn
}

output "s3_log_bucket_name" {
  value = module.data.s3_log_bucket_name
}

output "bastion_instance_id" {
  value = module.bastion.instance_id
}
