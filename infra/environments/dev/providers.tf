provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      Project   = local.project
      Env       = local.env
      ManagedBy = "Terraform"
    }
  }
}
