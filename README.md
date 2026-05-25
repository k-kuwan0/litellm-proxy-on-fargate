このリポジトリは下記の記事の実践に使用した内容です。  
詳細はそちらをご覧ください。  
[LiteLLM ProxyをECS Fargateにデプロイする構成をTerraform + ecspressoで組んでみた](https://dev.classmethod.jp/articles/litellm-proxy-on-fargate/)

[LiteLLM の s3_use_team_prefix と s3_use_key_prefix の挙動を検証して Team と Key 命名の方針を考えてみた](https://dev.classmethod.jp/articles/litellm-s3-prefix-team-key/)

[LiteLLM ProxyのRDSパスワード認証からIAM認証に切り替えてパスワードローテーションに強くしてみた](https://dev.classmethod.jp/articles/litellm-rds-iam-db-auth/)

# litellm-proxy-on-fargate

LiteLLM Proxy を ECS Fargate に乗せる構成のサンプル。LiteLLM 公式 / AWS Solutions Library のリファレンス実装をベースに、本番運用を想定したベストプラクティス（private VPC + VPC Endpoint / Secrets Manager / bastion 経由 SSM アクセス / ECS Exec / S3 リクエストログ / Bedrock 最小権限など）を反映している。Terraform で土台を作り、ecspresso で ECS Service / TaskDefinition のデプロイを回す。

## 構成

```
ローカル PC
  ↓ aws ssm start-session (PortForwardingToRemoteHost)
bastion (private subnet, public IP なし)
  ↓ ALB DNS:4000 へ forward
internal ALB (private subnet)
  ↓
ECS Service (LiteLLM Proxy on Fargate, port 4000)
  ↓ DATABASE_*
RDS (private subnet, PostgreSQL 16)
```

- VPC は **全 private 構成**。インターネット向け通信は VPC Endpoint（S3 Gateway + Interface×8）経由
- LiteLLM の `s3_v2` callback で S3 にリクエストログを PUT
- Secrets Manager に `LITELLM_MASTER_KEY` / `LITELLM_SALT_KEY` / RDS master user secret（AWS managed）を格納
- Bedrock 呼び出しはタスクロール経由。許可は使用するモデル ARN のみに絞る
- bastion 経由で SSM port forward して動作確認 / ECS Exec でコンテナ操作（API 呼び出しの監査は CloudTrail の `ExecuteCommand` イベントで完結）

## ディレクトリ

```
litellm-proxy-on-fargate/
├── infra/                      # Terraform（土台）— 詳細は infra/README.md
│   ├── bootstrap/
│   ├── modules/                # network / data / compute / bastion
│   └── environments/dev/
└── llm-gateway/                # LiteLLM 本体 + ecspresso — 詳細は llm-gateway/README.md
    ├── docker-compose.yaml     # ローカル開発用
    ├── litellm/                # Dockerfile / config
    ├── ecspresso/              # ECS Service / TaskDefinition
    └── Makefile                # build / push / deploy
```

## 前提

- Terraform >= 1.10.0
- AWS Provider 5.x
- ecspresso v2.x
- aws-cli v2 + Session Manager plugin
- docker（arm64 build を行うため Apple Silicon / buildx 環境を想定）

## デプロイ全体フロー

```sh
# 1. Terraform 土台を作る
cd infra/bootstrap && ./create-state-bucket.sh
cd ../environments/dev
terraform init && terraform apply

# 2. LiteLLM image を build / push して ecspresso で deploy
cd ../../../llm-gateway
make deploy

# 3. 動作確認（bastion 経由）
aws-vault exec <profile> -- aws ssm start-session \
  --target $(cd ../infra/environments/dev && aws-vault exec <profile> -- terraform output -raw bastion_instance_id) \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$(cd ../infra/environments/dev && aws-vault exec <profile> -- terraform output -raw alb_dns_name),portNumber=4000,localPortNumber=4000"
# 別シェルで
curl http://localhost:4000/health/liveliness
```

詳細手順:
- Terraform 側 → [infra/README.md](infra/README.md)
- LiteLLM / ecspresso 側 → [llm-gateway/README.md](llm-gateway/README.md)

## クリーンアップ

```sh
cd llm-gateway/ecspresso && ecspresso delete --force --terminate
cd ../../infra/environments/dev && terraform destroy
```

state bucket は手動削除（バージョニング有効のため versions も含めて削除する必要あり）。
