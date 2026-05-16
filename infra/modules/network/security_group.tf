resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Internal ALB for LiteLLM Proxy"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_security_group" "service" {
  name        = "${var.project_name}-service"
  description = "ECS Service for LiteLLM Proxy"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-service"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds"
  description = "RDS for LiteLLM Proxy"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-rds"
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion"
  description = "Bastion host for SSM port forwarding"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

resource "aws_security_group" "endpoints" {
  name        = "${var.project_name}-endpoints"
  description = "VPC Interface Endpoints"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_bastion" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
  description                  = "LiteLLM port from bastion"
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  security_group_id            = aws_security_group.service.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
  description                  = "LiteLLM port from ALB"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_service" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.service.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from ECS service"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_service" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.service.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from ECS service"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_bastion" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from bastion"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "service_all" {
  security_group_id = aws_security_group.service.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "endpoints_all" {
  security_group_id = aws_security_group.endpoints.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
