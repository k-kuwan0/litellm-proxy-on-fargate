-- RDS IAM database authentication で接続する PostgreSQL ユーザーを作成する。
-- Terraform で RDS クラスタが作成された後、bastion から master user で接続して
-- 一度だけ実行する。冪等なので再実行しても安全。
--
-- 環境変数:
--   APP_USER   ECS タスクが IAM トークンで接続するユーザー名
--              (Terraform output `db_app_username` の値、デフォルト litellm_app)
--   DB_NAME    対象データベース名
--              (Terraform output `db_name` の値、デフォルト litellm)
--
-- 実行例 (bastion 内):
--   psql -h <RDS_ENDPOINT> -p 5432 -U <DB_MASTER_USER> -d <DB_NAME> \
--        -v ON_ERROR_STOP=1 \
--        -v APP_USER=litellm_app \
--        -v DB_NAME=litellm \
--        -f bootstrap.sql
--
-- 詳細は docs/iam-db-auth.md を参照。

-- ユーザーが既に存在していれば何もしない (idempotent)
DO $$
BEGIN
  CREATE USER :"APP_USER";
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- IAM トークン認証を受け付けるための AWS 予約ロール
GRANT rds_iam TO :"APP_USER";

-- DB 接続と作業権限
GRANT ALL PRIVILEGES ON DATABASE :"DB_NAME" TO :"APP_USER";
GRANT ALL ON SCHEMA public TO :"APP_USER";

-- Prisma migration がこれから作るテーブル/シーケンスにも権限が及ぶように
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO :"APP_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO :"APP_USER";

-- 確認
SELECT rolname FROM pg_roles WHERE rolname = :'APP_USER';
SELECT r.rolname AS member, g.rolname AS granted_role
FROM pg_auth_members m
JOIN pg_roles r ON m.member = r.oid
JOIN pg_roles g ON m.roleid = g.oid
WHERE r.rolname = :'APP_USER';
