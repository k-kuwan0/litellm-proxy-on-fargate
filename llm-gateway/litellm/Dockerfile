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
#  Secrets:
#    LITELLM_MASTER_KEY     ... 管理 API 認証
#    LITELLM_SALT_KEY       ... DB 暗号化 salt
#    UI_PASSWORD            ... Admin UI ログイン用 (master key と同値)
#    DATABASE_USERNAME      ... PostgreSQL 接続ユーザー
#    DATABASE_PASSWORD      ... PostgreSQL 接続パスワード
#
#  Environment:
#    AWS_DEFAULT_REGION     ... AWS リージョン
#    DATABASE_HOST          ... PostgreSQL ホスト名
#    DATABASE_PORT          ... PostgreSQL ポート
#    S3_LOG_BUCKET_NAME     ... リクエストログ出力先 S3 bucket 名
#    UI_USERNAME            ... Admin UI ログイン用 (例: admin)
# ════════════════════════════════════════════════════════════════════

