terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.55"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

locals {
  project_name = "ecommerce-platform"
  name_prefix  = "${local.project_name}-${var.environment}"
  services     = ["frontend", "login", "orders", "payments", "inventory", "catalog"]
}

data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = var.bootstrap_state_bucket
    key    = "${var.bootstrap_state_prefix}/${var.environment}/terraform.tfstate"
    region = var.region
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

module "rds" {
  source = "../../modules/rds"

  identifier                   = "${local.name_prefix}-orders-db"
  engine_version               = "15.5"
  instance_class               = "db.m7g.large"
  allocated_storage            = 200
  max_allocated_storage        = 600
  multi_az                     = true
  db_name                      = "ecommerce"
  username                     = "appadmin"
  kms_key_arn                  = data.terraform_remote_state.bootstrap.outputs.kms_general_arn
  subnet_ids                   = data.terraform_remote_state.bootstrap.outputs.private_data_subnet_ids
  vpc_id                       = data.terraform_remote_state.bootstrap.outputs.vpc_id
  allowed_security_group_ids   = [data.terraform_remote_state.bootstrap.outputs.cluster_security_group_id]
  backup_retention             = 14
  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  deletion_protection          = true
  environment                  = var.environment

  tags = { Environment = var.environment, Project = local.project_name }
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = {
    for service in local.services :
    "ecom-${service}" => {
      scan_on_push = true
      mutable_tags = false
    }
  }

  kms_key_arn = data.terraform_remote_state.bootstrap.outputs.kms_general_arn
  tags        = { Environment = var.environment, Project = local.project_name }
}

module "observability" {
  source = "../../modules/observability"

  name            = "${local.name_prefix}-obs"
  region          = var.region
  alert_endpoints = var.alert_emails
  tags            = { Environment = var.environment, Project = local.project_name }
}

