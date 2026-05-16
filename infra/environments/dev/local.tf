locals {
  project    = "litellm-proxy"
  env        = "dev"
  aws_region = "ap-northeast-1"

  name_prefix        = "${local.project}-${local.env}"
  vpc_cidr           = "10.0.0.0/16"
  db_master_username = "litellm"
}
