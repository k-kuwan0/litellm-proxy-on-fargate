TF_DIR    := ../infra/environments/dev
ECR_URL   := $(shell cd $(TF_DIR) && terraform output -raw ecr_repository_url)
REGION    := $(shell cd $(TF_DIR) && terraform output -raw aws_region)
SHORT_SHA ?= $(shell git rev-parse --short=7 HEAD)
IMAGE_TAG := $(ECR_URL):$(SHORT_SHA)

.PHONY: login build push deploy diff status logs

login:
	aws ecr get-login-password --region $(REGION) \
	  | docker login --username AWS --password-stdin $(ECR_URL)

build:
	docker build --platform linux/arm64 -t $(IMAGE_TAG) ./litellm

push: login build
	docker push $(IMAGE_TAG)

deploy: push
	cd ecspresso && IMAGE_TAG=$(IMAGE_TAG) ecspresso deploy

diff:
	cd ecspresso && IMAGE_TAG=$(IMAGE_TAG) ecspresso diff

status:
	cd ecspresso && ecspresso status --events 10

logs:
	cd ecspresso && ecspresso tasks --output json | jq -r '.[0].taskArn'
