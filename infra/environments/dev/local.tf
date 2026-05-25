locals {
  project    = "litellm-proxy"
  env        = "dev"
  aws_region = "ap-northeast-1"

  name_prefix        = "${local.project}-${local.env}"
  vpc_cidr           = "10.0.0.0/16"
  db_master_username = "litellm"
  # ECS タスクが IAM トークンで接続する PostgreSQL ユーザー名。
  # 初回 apply 後に master_username で接続して
  #   CREATE USER {db_app_username};
  #   GRANT rds_iam TO {db_app_username};
  # を一度だけ実行する必要がある (詳細は docs/iam-db-auth.md)。
  db_app_username = "litellm_app"
}
