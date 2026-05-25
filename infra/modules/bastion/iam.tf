data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project_name}-bastion"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# bootstrap SQL 実行時にマスターパスワードを Secrets Manager から取得するために必要。
# 緊急時の break-glass 用途にも使う。
data "aws_iam_policy_document" "rds_master_secret_read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.rds_master_user_secret_arn]
  }
}

resource "aws_iam_role_policy" "rds_master_secret_read" {
  name   = "rds-master-secret-read"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.rds_master_secret_read.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-bastion"
  role = aws_iam_role.this.name
}
