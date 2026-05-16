resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/litellm/app"
  retention_in_days = 7
}
