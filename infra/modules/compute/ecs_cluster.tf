resource "aws_ecs_cluster" "this" {
  name = var.project_name

  # ECS Exec のセッショントランスクリプト (シェル内で打ったコマンドと
  # 出力) を CloudWatch / S3 に残すには、コンテナイメージに BSD 版
  # script コマンドが必要 (AWS 公式要件)。LiteLLM の image base である
  # Wolfi/Chainguard には BSD script が提供されておらず、util-linux 版
  # script は SSM agent の引数構文と非互換のため、トランスクリプトは
  # 残せない。NONE を明示することで意図を示す。
  #
  # ECS Exec API 呼び出し自体 (誰が・いつ・どのタスク・コンテナに対し、
  # 非対話なら何を実行したか) は CloudTrail の ExecuteCommand イベントに
  # 自動記録される。
  configuration {
    execute_command_configuration {
      logging = "NONE"
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
