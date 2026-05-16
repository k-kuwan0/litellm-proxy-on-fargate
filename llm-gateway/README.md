# LLM Gateway

LiteLLM Proxy を中心とした LLM Gateway。ローカル開発（docker compose）と ECS Fargate へのデプロイ（ecspresso）の両方をこのディレクトリで扱う。

AWS インフラ側（Terraform）については [../infra/README.md](../infra/README.md) を参照。

## ディレクトリ構成

```
llm-gateway/
├── docker-compose.yaml        # ローカル開発用 compose（LiteLLM / PostgreSQL / MinIO）
├── Makefile                   # ECR への build / push + ecspresso deploy
├── litellm/
│   ├── Dockerfile             # LiteLLM コンテナイメージ（config.yaml 同梱）
│   ├── config.yaml            # ECS 環境用の LiteLLM 設定
│   └── config.local.yaml      # ローカル開発用の LiteLLM 設定（MinIO 向け S3 callback）
├── ecspresso/                 # ECS Service / TaskDefinition
│   ├── ecspresso.yml          # cluster / service / tfstate plugin の設定
│   ├── service-def.json       # Fargate / TG attach / circuit breaker / ECS Exec / grace period 300s
│   └── task-def.json          # 4vCPU/8GB ARM64 / secrets 注入 (RDS / master key / salt key / UI password)
└── database/
    ├── postgresql/            # PostgreSQL データ（.gitignore 対象）
    └── minio/                 # MinIO データ（.gitignore 対象）
```

---

## ECS Fargate へのデプロイ

### 前提

- [../infra/README.md](../infra/README.md) の手順で `terraform apply` が完了していること
- ecspresso v2.x が手元に入っていること（`brew install kayac/tap/ecspresso`）
- docker が arm64 build を行える状態（Apple Silicon / Linux + buildx）

### Makefile によるデプロイ

```sh
aws-vault exec <profile> -- make deploy
```

これで以下が一気に走る:

1. `terraform output` から ECR URL / region を取得
2. `git rev-parse --short=7 HEAD` で image tag を生成（例: `352c5d0`）
3. ECR にログイン
4. `docker build --platform linux/arm64 -t <ECR>:<SHA> ./litellm`
5. `docker push <ECR>:<SHA>`
6. `IMAGE_TAG=<ECR>:<SHA> ecspresso deploy`

### Makefile のターゲット

| ターゲット | 用途 |
|---|---|
| `login` | ECR に docker login |
| `build` | image を arm64 build |
| `push` | login + build + push |
| `deploy` | push + ecspresso deploy |
| `diff` | ecspresso diff（task-def / service-def の差分確認） |
| `status` | ecspresso status |

`SHORT_SHA` を環境変数で上書きすれば任意のタグでデプロイ可能。

```sh
aws-vault exec <profile> -- make SHORT_SHA=v0.0.1 deploy
```

### ecspresso が tfstate から参照する値

`ecspresso/task-def.json` / `service-def.json` 内の `{{ tfstate `output.<name>` }}` で、[../infra/environments/dev/outputs.tf](../infra/environments/dev/outputs.tf) の各 output を参照する。`ecspresso.yml` の `plugins.tfstate.config.url` が S3 上の tfstate を指している。

### 動作確認（bastion 経由）

bastion に SSM port forward して、ローカルから ALB:4000 に到達できる状態を作る。

```sh
BASTION_ID=$(cd ../infra/environments/dev && aws-vault exec <profile> -- terraform output -raw bastion_instance_id)
ALB_DNS=$(cd ../infra/environments/dev && aws-vault exec <profile> -- terraform output -raw alb_dns_name)

aws-vault exec <profile> -- aws ssm start-session \
  --target ${BASTION_ID} \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=${ALB_DNS},portNumber=4000,localPortNumber=4000"
```

別シェルで疎通確認:

```sh
curl -i http://localhost:4000/health/liveliness
# 期待: HTTP/1.1 200 OK
```

### Admin UI へのログイン

port forward が動いている状態でブラウザから `http://localhost:4000/ui` を開く。

- **ユーザー名**: `admin`（`UI_USERNAME` 環境変数で設定済み）
- **パスワード**: `LITELLM_MASTER_KEY` の値（Secrets Manager に格納）

master key の取得:

```sh
MASTER_KEY_ARN=$(cd ../infra/environments/dev && aws-vault exec <profile> -- terraform output -raw master_key_secret_arn)
aws-vault exec <profile> -- aws secretsmanager get-secret-value \
  --secret-id "${MASTER_KEY_ARN}" \
  --query SecretString --output text
```

出力された `sk-...` 形式の文字列をブラウザの password 欄に貼り付ける（macOS でクリップボードに送るなら末尾に `| pbcopy` を付与）。

### Bedrock モデルの登録（Admin UI）

`general_settings.store_model_in_db: true` でモデル定義は DB に保存される。Admin UI から登録:

1. 左メニュー **「Models + Endpoints」** → **「+ Add Model」**
2. 以下を入力:
   - **Provider**: `Bedrock`
   - **LiteLLM Model Name(s)**: `bedrock/amazon.nova-lite-v1:0`
   - **Public Model Name**: `nova-lite`（任意の表示名）
   - **AWS Region Name**: `ap-northeast-1`
   - **AWS Access Key ID / Secret**: 空欄（タスクロール経由）

別モデルを追加する場合は [`../infra/modules/compute/iam.tf`](../infra/modules/compute/iam.tf) の `BedrockInvoke` ステートメントに ARN を追加する。

### ECS Exec で直接コンテナに入る

```sh
CLUSTER=$(cd ../infra/environments/dev && aws-vault exec <profile> -- terraform output -raw ecs_cluster_name)
TASK=$(aws-vault exec <profile> -- aws ecs list-tasks --cluster ${CLUSTER} --service-name litellm --query 'taskArns[0]' --output text)

aws-vault exec <profile> -- aws ecs execute-command \
  --cluster ${CLUSTER} \
  --task ${TASK} \
  --container litellm \
  --interactive \
  --command "/bin/sh"
```

ECS Exec の API 呼び出し（誰がいつどのタスク・コンテナに、非対話モードで何を実行したか）は **CloudTrail の `ExecuteCommand` イベント** に自動記録される。対話シェル内のトランスクリプト（シェル内で打った各コマンドと出力）を CloudWatch / S3 に残すには、コンテナイメージに BSD 版 `script` コマンドが必要だが、LiteLLM image のベースである Wolfi/Chainguard には提供されていないため取得していない。

### Prisma migration の手動操作

LiteLLM 起動時に `USE_PRISMA_MIGRATE=True` で `prisma migrate deploy` が自動実行される。必要に応じて ECS Exec から手動でも操作可能。

```sh
# コンテナに入った後
cd /app/.venv/lib/python3.13/site-packages/litellm_proxy_extras

# パスワードを URL エンコード（RDS 自動生成パスワードに / 等が含まれることがあるため）
ENC_PW=$(python3 -c "import os, urllib.parse; print(urllib.parse.quote(os.environ['DATABASE_PASSWORD'], safe=''))")

DATABASE_URL="postgresql://${DATABASE_USERNAME}:${ENC_PW}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}" \
  prisma migrate status --schema schema.prisma
```

主なサブコマンド:

| コマンド | 用途 |
|---|---|
| `prisma migrate status` | 適用状態の確認 |
| `prisma migrate deploy` | 未適用の migration を流す |
| `prisma migrate resolve --rolled-back <name>` | 失敗 migration を「ロールバック済み」とマークする |
| `prisma db execute --file <sql>` | 任意 SQL の実行 |

### クリーンアップ

```sh
cd ecspresso && aws-vault exec <profile> -- ecspresso delete --force --terminate
```

これで ECS Service / Task Definition が削除される。Terraform 側の destroy は [../infra/README.md](../infra/README.md) を参照。

---

## ローカル開発

### config.yaml と config.local.yaml の使い分け

- **config.yaml**: Dockerfile に同梱され、ECS 環境で使われる。AWS S3 / Bedrock にはタスクロールで認証する前提。
- **config.local.yaml**: docker-compose.yaml が `/app/config.yaml` にマウントすることで上書きする。ローカルの S3 互換ストレージ（MinIO）に対するエンドポイント / クレデンシャル / path-style を指定する。

### 起動方法

```bash
cd llm-gateway
docker compose up --build
```

| サービス | URL | 用途 |
|---|---|---|
| LiteLLM Proxy | http://localhost:4000 | API エンドポイント |
| LiteLLM Admin UI | http://localhost:4000/ui | モデル / ガードレール登録 |
| MinIO Console | http://localhost:9001 | S3 callback の書き込み先を目視確認 |
| PostgreSQL | localhost:5432 | LiteLLM の永続化先 |

### 認証情報（ローカル）

| 対象 | ユーザー / キー | パスワード |
|---|---|---|
| LiteLLM Admin UI | master key: `sk-local-dev-key` | - |
| MinIO Console | `minioadmin` | `minioadmin` |

すべて docker-compose.yaml に直書きしている（ローカル限定の値）。

### 設定変更

LiteLLM の設定は基本的に Admin UI から行い、DB に保存される。config.local.yaml は環境変数で切り替える必要があるもの、および挙動への影響が大きく変更を慎重に管理したいもの（ログ出力先など）に限定して扱う。

#### モデルの登録（Admin UI）

`general_settings.store_model_in_db: true` により、モデル定義は DB から読み込まれる（config.local.yaml に `model_list` は記述しない）。Admin UI の Models > Add Model からモデルを登録する。

Bedrock の推論プロファイルを使う場合は「Custom Model Name」を選択し、`bedrock/jp.anthropic.claude-sonnet-4-6` のように入力する。

ローカル開発で実際の Bedrock を呼び出す場合は、モデル登録時の AWS クレデンシャル欄に aws-vault などで取得した一時クレデンシャル（Access Key ID / Secret Access Key / Session Token）を入力する。セッショントークンの有効期限が切れたら、モデル定義のクレデンシャルも更新する。

#### ガードレールの設定（Admin UI）

ガードレールも Admin UI から設定する。Bedrock Guardrails のバージョン更新に追従しやすくするため、`guardrailIdentifier` / `guardrailVersion` を UI で管理する運用にしている。

1. http://localhost:4000/ui にログイン
2. 左メニュー「Guardrails」を選択
3. 「+ Add Guardrail」をクリック
4. 以下を入力:
   - **Guardrail Name**: `platform-guardrail`
   - **Provider**: `bedrock`
   - **Mode**: `during_call`
   - **guardrailIdentifier**: Bedrock Guardrails の ID（例: `0ikaa3sxgcg7`）
   - **guardrailVersion**: バージョン番号（例: `2`）
   - **aws_region_name**: `ap-northeast-1`
   - **default_on**: 有効

UI から登録したガードレールは DB に保存されるため、Guardrails Monitor の詳細画面（Performance / Logs）も利用可能になる。

#### S3 ログ出力（config.local.yaml）

config.local.yaml は LiteLLM の S3 callback を MinIO に向ける設定を持つ。MinIO のコンソールから書き込まれたログを目視確認できる。

config.local.yaml の編集後は `docker compose restart litellm` で反映できる（compose は config.local.yaml を `/app/config.yaml` にマウントしている）。

### 環境変数（docker-compose.yaml）

| 変数 | 用途 | 値 |
|---|---|---|
| `CONFIG_FILE_PATH` | config.yaml のパス | `/app/config.yaml` |
| `LITELLM_MASTER_KEY` | 管理者認証キー | `sk-local-dev-key` |
| `DATABASE_URL` | PostgreSQL 接続文字列 | `postgresql://litellm:litellm@postgres:5432/litellm` |
| `AWS_DEFAULT_REGION` | AWS リージョン | `ap-northeast-1` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` | コンテナ内 AWS SDK のデフォルトクレデンシャル | `minioadmin` / `minioadmin` / 空文字 |
| `S3_LOG_BUCKET_NAME` | LiteLLM が書き込むログバケット名 | `litellm-logs` |
| `S3_ENDPOINT_URL` | S3 互換エンドポイント（MinIO） | `http://minio:9000` |
| `S3_AWS_ACCESS_KEY_ID` / `S3_AWS_SECRET_ACCESS_KEY` | S3 callback 専用のクレデンシャル（MinIO 用、`s3_callback_params` から参照） | `minioadmin` / `minioadmin` |

`AWS_*` を MinIO 用に固定しているのは、シェル環境のセッショントークンが流入すると S3 callback の署名検証に失敗するため。Bedrock 呼び出し用のクレデンシャルは Admin UI でモデル登録時に個別に入力する。

### データの初期化

PostgreSQL のデータを初期化したい場合:

```bash
docker compose down
rm -rf database/postgresql
docker compose up --build
```

MinIO のデータを初期化したい場合:

```bash
docker compose down
rm -rf database/minio
docker compose up --build
```
