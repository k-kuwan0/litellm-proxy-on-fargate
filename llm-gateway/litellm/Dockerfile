FROM ghcr.io/berriai/litellm:v1.83.14-stable.patch.3

# config 設定を Image に同梱する
COPY config.yaml /app/config.yaml

# LiteLLM 起動方針 (Dockerfile で固定する値、ホスト側でも上書き可能)
ENV CONFIG_FILE_PATH=/app/config.yaml
ENV LITELLM_LOG=INFO
ENV LITELLM_MODE=PRODUCTION
ENV DATABASE_NAME=litellm
ENV USE_PRISMA_MIGRATE=True

# ════════════════════════════════════════════════════════════════════
#  HOST-INJECTED ENVIRONMENT VARIABLES
#  以下はホスト側 (TaskDefinition / docker-compose) で注入が必要
#
#  Secrets (Secrets Manager 経由):
#    LITELLM_MASTER_KEY     ... 管理 API 認証
#    LITELLM_SALT_KEY       ... DB 暗号化 salt
#    UI_PASSWORD            ... Admin UI ログイン用 (master key と同値)
#
#  Environment:
#    AWS_DEFAULT_REGION     ... AWS リージョン
#    AWS_REGION             ... 同上 (IAM トークン署名で boto3 が参照)
#    AWS_REGION_NAME        ... 同上
#    IAM_TOKEN_DB_AUTH      ... "true" で RDS IAM 認証を有効化
#    DATABASE_HOST          ... PostgreSQL ホスト名
#    DATABASE_PORT          ... PostgreSQL ポート
#    DATABASE_NAME          ... 接続先 DB 名
#    DATABASE_USER          ... IAM 認証で接続する PostgreSQL ユーザー
#    S3_LOG_BUCKET_NAME     ... リクエストログ出力先 S3 bucket 名
#    UI_USERNAME            ... Admin UI ログイン用 (例: admin)
#
#  認証:
#    本番では RDS IAM database authentication を使用する。
#    DATABASE_USERNAME / DATABASE_PASSWORD は不要。
# ════════════════════════════════════════════════════════════════════

