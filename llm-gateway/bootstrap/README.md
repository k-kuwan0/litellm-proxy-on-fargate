# bootstrap

RDS IAM database authentication を成立させるために、
**RDS クラスタ初回作成時に一度だけ** PostgreSQL 側で実行する SQL を置く。

## なぜ必要か

ECS タスクは IAM トークンで PostgreSQL に接続するが、トークンを受け付けるユーザーは
PostgreSQL 内に明示的に作成し、AWS 予約ロール `rds_iam` を付与する必要がある。
これは AWS のマネージドサービスとしての制約で、Terraform で完結できない。

詳細は [docs/iam-db-auth.md](../../docs/iam-db-auth.md) を参照。

## 中身

- `bootstrap.sql` — `litellm_app` ユーザー作成と権限付与。冪等。

## 実行方法

RDS は private subnet にあるので、bastion 経由で実行する。

### 1. bastion に SSM Session で入る

```bash
BASTION_ID=$(cd ../../infra/environments/dev && terraform output -raw bastion_instance_id)
aws-vault exec terraform-runner -- aws ssm start-session --target "$BASTION_ID"
```

### 2. bastion 内で psql を準備

```bash
sudo dnf install -y postgresql17
```

### 3. 接続情報をセットして SQL を流す

```bash
export AWS_DEFAULT_REGION=ap-northeast-1

# Terraform output を事前に手元で確認して値を貼る
DB_HOST="<rds_endpoint>"
DB_NAME="<db_name>"           # 例: litellm
DB_MASTER_USER="<db_master_username>"  # 例: litellm
APP_USER="<db_app_username>"  # 例: litellm_app
SECRET_ARN="<rds_master_user_secret_arn>"

export PGPASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString --output text | jq -r .password)

# SQL をローカルから bastion に転送するのが面倒なら、ヒアドキュメントで流す手もある
# (bootstrap.sql の内容をそのまま貼って実行)
psql -h "$DB_HOST" -p 5432 -U "$DB_MASTER_USER" -d "$DB_NAME" \
     -v ON_ERROR_STOP=1 \
     -v APP_USER="$APP_USER" \
     -v DB_NAME="$DB_NAME" \
     -f bootstrap.sql
```

### 期待される出力

```text
   rolname
-------------
 litellm_app
(1 row)

   member    | granted_role
-------------+--------------
 litellm_app | rds_iam
(1 row)
```

`litellm_app | rds_iam` の行が出れば成功。

## 再実行について

bootstrap.sql は冪等に書いてあるので、何度実行しても害はない:

- `CREATE USER` は `DO $$ ... EXCEPTION WHEN duplicate_object` でラップ
- `GRANT` 系は既に持っている権限を再付与しても no-op
- `ALTER DEFAULT PRIVILEGES` も同じ設定を再適用するだけ

RDS クラスタを作り直した場合は再実行が必要。

## 今後の改善余地

Terraform 完結で自動化したい場合の候補:

- VPC 内 Lambda + `aws_lambda_invocation` で psycopg2 から SQL を流す
  ([AWS CDK 公式パターン](https://aws.amazon.com/blogs/infrastructure-and-automation/use-aws-cdk-to-initialize-amazon-rds-instances/) の Terraform 版)
- BerriAI 公式は `terraform_data` + `local-exec` で ECS run-task を起動
  ([bootstrap.tf](https://github.com/BerriAI/litellm/blob/litellm_internal_staging/terraform/litellm/aws/bootstrap.tf))
