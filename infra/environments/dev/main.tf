module "network" {
  source = "../../modules/network"

  project_name = local.name_prefix
  vpc_cidr     = local.vpc_cidr
}

module "data" {
  source = "../../modules/data"

  project_name          = local.name_prefix
  private_subnet_ids    = module.network.private_subnet_ids
  rds_security_group_id = module.network.rds_security_group_id
  db_master_username    = local.db_master_username
}

module "compute" {
  source = "../../modules/compute"

  project_name               = local.name_prefix
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  alb_security_group_id      = module.network.alb_security_group_id
  rds_master_user_secret_arn = module.data.rds_master_user_secret_arn
  master_key_secret_arn      = module.data.master_key_secret_arn
  salt_key_secret_arn        = module.data.salt_key_secret_arn
  s3_log_bucket_arn          = module.data.s3_log_bucket_arn
}

module "bastion" {
  source = "../../modules/bastion"

  project_name              = local.name_prefix
  private_subnet_ids        = module.network.private_subnet_ids
  bastion_security_group_id = module.network.bastion_security_group_id
}
