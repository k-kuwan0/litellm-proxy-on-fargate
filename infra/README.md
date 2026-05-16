# infra

LiteLLM Proxy on Fargate の AWS インフラを Terraform で構築する。ECS Service / TaskDefinition は [llm-gateway/ecspresso/](../llm-gateway/ecspresso/) に切り出している。

LiteLLM 公式 / AWS Solutions Library のリファレンス実装をベースに、本番運用を想定したベストプラクティス（private VPC + VPC Endpoint / Secrets Manager / AWS managed RDS master password / Bedrock 最小権限 / ECS Exec + CloudTrail 監査 / bastion 経由 SSM アクセス）を反映している。

## ディレクトリ

```
infra/
├── bootstrap/
│   └── create-state-bucket.sh        # state 用 S3 バケットを作るシェル
├── modules/                          # 環境間で共有
│   ├── network/                      # VPC / Subnet / SG / VPC Endpoint
│   ├── data/                         # RDS / Secrets Manager / S3 / LogGroup
│   ├── compute/                      # ECS Cluster / ALB / ECR / IAM Role
│   └── bastion/                      # EC2 + SSM
└── environments/
    └── dev/                          # 環境エントリポイント
        ├── backend.tf                # S3 backend（use_lockfile = true）
        ├── local.tf                  # project / env / aws_region 等
        ├── main.tf                   # module 呼び出し
        ├── outputs.tf                # ecspresso が tfstate plugin で参照
        ├── providers.tf
        └── versions.tf
```

## 責務分担

| 層 | 担当 | リソース |
|---|---|---|
| **Terraform** | 一度作ったら頻繁に変えない土台 | VPC / VPC Endpoint / RDS / Secrets / S3 / ECS Cluster / ALB / Target Group / LogGroup / ECR / IAM Role / bastion |
| **ecspresso** | LiteLLM の deploy ライフサイクル | ECS Service / Task Definition / image tag rollout |

## module 概要

### network

- VPC（`10.0.0.0/16`）/ private subnet × 2 AZ（public subnet なし）
- IGW / NAT は **置かない**。外向き通信はすべて VPC Endpoint 経由
- Interface Endpoint: `ecr.api` / `ecr.dkr` / `logs` / `secretsmanager` / `ssm` / `ssmmessages` / `ec2messages` / `bedrock-runtime`
- Gateway Endpoint: `s3`
- SG: `alb` / `service` / `rds` / `bastion` / `endpoints` の 5 本

### data

- RDS PostgreSQL 16.6 / `db.t4g.micro` / シングル AZ / `storage_encrypted = true`
- `manage_master_user_password = true` で RDS master user secret を AWS が自動生成・ローテーション管理
- Secrets Manager: `LITELLM_MASTER_KEY` / `LITELLM_SALT_KEY`（Terraform 内で `random_password` 生成 → Secret に格納）
- S3 ログバケット（`force_destroy = true` / SSE AES256 / public access block 全有効）
- CloudWatch LogGroup（LiteLLM アプリ用、retention 7 日）

### compute

- ECS Cluster（Container Insights 有効、`execute_command_configuration.logging = "NONE"`：セッショントランスクリプトは取らず、API 呼び出しは CloudTrail で監査）
- internal ALB / Target Group（`/health/liveliness` で health check、`deregistration_delay = 60`）
- ECR repository（`IMMUTABLE` / scan on push）
- IAM Role 2 本:
  - **execution role**: `AmazonECSTaskExecutionRolePolicy` + Secrets Manager `GetSecretValue`（3 Secrets: master key / salt key / RDS master user secret）
  - **task role**: S3 PutObject（ログバケットのみ）/ Bedrock `InvokeModel` `InvokeModelWithResponseStream`（Nova Lite ARN に限定）/ ECS Exec の `ssmmessages:*`

### bastion

- AL2023 arm64 / `t4g.nano` / private subnet / public IP なし
- IMDSv2 必須、EBS 暗号化
- `AmazonSSMManagedInstanceCore` で SSM Session Manager 接続
- SG: `bastion → alb:4000` `bastion → endpoints:443` のみ許可（RDS へ直接アクセスはしない）

## デプロイ手順

### 1. state bucket を作る

```sh
cd bootstrap
./create-state-bucket.sh
```

デフォルト: bucket = `litellm-proxy-tfstate` / region = `ap-northeast-1`。変えるなら `BUCKET` / `REGION` 環境変数で上書き。

### 2. terraform apply

```sh
cd environments/dev
aws-vault exec <profile> -- terraform init
aws-vault exec <profile> -- terraform apply
```

VPC / VPC Endpoint / RDS / Secrets / S3 / ECS Cluster / ALB / ECR / bastion などが作られる。所要時間は **約 10〜15 分**（RDS 作成に時間がかかる）。

### 3. ecspresso に値を渡す

`outputs.tf` の各 output は ecspresso 側の tfstate plugin から `output.<name>` で参照される（[../llm-gateway/ecspresso/task-def.json](../llm-gateway/ecspresso/task-def.json) など）。

## クリーンアップ

```sh
# ECS Service を消してから Terraform を destroy する
cd ../../../llm-gateway/ecspresso && ecspresso delete --force --terminate
cd ../../infra/environments/dev && terraform destroy
```

state bucket は手動削除（バージョニング有効のため versions も含めて削除する必要あり）。

## 命名規則

`local.name_prefix = "${local.project}-${local.env}"`（例: `litellm-proxy-dev`）を module の `project_name` 引数に渡し、リソース名のプレフィックスとして使う。環境を増やす場合は `environments/<env>/` を複製して `local.tf` の `env` を変更する。
