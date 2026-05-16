resource "aws_secretsmanager_secret" "master_key" {
  name                    = "${var.project_name}/litellm/master-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "master_key" {
  secret_id     = aws_secretsmanager_secret.master_key.id
  secret_string = "sk-${random_password.master_key.result}"
}

resource "aws_secretsmanager_secret" "salt_key" {
  name                    = "${var.project_name}/litellm/salt-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "salt_key" {
  secret_id     = aws_secretsmanager_secret.salt_key.id
  secret_string = random_password.salt_key.result
}
