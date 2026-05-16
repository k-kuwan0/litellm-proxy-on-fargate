resource "aws_ecr_repository" "litellm" {
  name                 = "${var.project_name}/litellm"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
