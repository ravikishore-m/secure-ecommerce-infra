resource "random_password" "master" {
  length              = 20
  override_characters = "!@#%^*-_=+"
  special             = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.identifier}-credentials"
  description = "Master credentials for ${var.identifier}"

  tags = merge(var.tags, {
    Name = "${var.identifier}-secret"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.master.result
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "SG access"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.identifier}-pg"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier                   = var.identifier
  engine                       = "postgres"
  engine_version               = var.engine_version
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  multi_az                     = var.multi_az
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.this.id]
  db_name                      = var.db_name
  username                     = var.username
  password                     = random_password.master.result
  port                         = 5432
  storage_encrypted            = true
  kms_key_id                   = var.kms_key_arn
  backup_retention_period      = var.backup_retention
  delete_automated_backups     = true
  deletion_protection          = var.deletion_protection
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_role_arn
  auto_minor_version_upgrade   = true
  publicly_accessible          = false
  apply_immediately            = false
  parameter_group_name         = aws_db_parameter_group.this.name

  tags = merge(var.tags, {
    Environment = var.environment
  })

  lifecycle {
    prevent_destroy = var.environment == "prod"
  }
}

