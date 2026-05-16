terraform {
  backend "s3" {
    bucket       = "litellm-proxy-tfstate"
    key          = "terraform/dev/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
