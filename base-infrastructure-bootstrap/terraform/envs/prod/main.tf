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

provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn     = var.assume_role_arn
      session_name = "terraform-${var.environment}"
    }
  }

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "ecommerce-platform"
      Owner       = var.owner
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  project_name = "ecommerce-platform"
  name_prefix  = "${local.project_name}-${var.environment}"
  fqdn_prefix  = "${var.environment}.${var.root_domain}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
  github_subjects = [
    for repo in var.github_repositories :
    "repo:${repo}:environment:${var.environment}"
  ]

  cidr_block                = "10.30.0.0/16"
  public_subnet_cidrs       = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
  private_app_subnet_cidrs  = ["10.30.128.0/19", "10.30.160.0/19", "10.30.192.0/19"]
  private_data_subnet_cidrs = ["10.30.240.0/22", "10.30.244.0/22", "10.30.248.0/22"]

  services = ["frontend", "login", "orders", "payments", "inventory", "catalog"]

  ingress_routes = {
    frontend = {
      priority = 5
      path     = "/*"
    }
    login = {
      priority = 10
      path     = "/login*"
    }
    orders = {
      priority = 20
      path     = "/orders*"
    }
    payments = {
      priority = 30
      path     = "/payments*"
    }
    inventory = {
      priority = 40
      path     = "/inventory*"
    }
    catalog = {
      priority = 50
      path     = "/catalog*"
    }
  }

  node_groups = {
    general = {
      desired_size   = 3
      min_size       = 2
      max_size       = 6
      instance_types = ["m7g.large"]
      capacity_type  = "ON_DEMAND"
      labels = {
        workload = "general"
      }
    }
    spot = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["m6g.large"]
      capacity_type  = "SPOT"
      labels = {
        workload = "spot"
      }
    }
  }
}

resource "aws_kms_key" "general" {
  description             = "General purpose key for ${local.name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = true
  tags = {
    Environment = var.environment
    Purpose     = "general"
    Project     = local.project_name
  }
}

resource "aws_kms_alias" "general" {
  name          = "alias/${local.project_name}/${var.environment}/general"
  target_key_id = aws_kms_key.general.key_id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/${local.project_name}/${var.environment}/vpc-flow"
  retention_in_days = 180
  kms_key_id        = aws_kms_key.general.arn
  tags = {
    Environment = var.environment
    Project     = local.project_name
  }
}

locals {
  cluster_oidc_provider_url = replace(module.eks.cluster_oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
}

module "dns" {
  source      = "../../../../terraform/modules/dns"
  root_domain = var.root_domain
  create_zone = var.create_hosted_zone
  subject_alternative_names = [
    "*.${var.root_domain}",
    "*.${local.fqdn_prefix}"
  ]

  tags = {
    Environment = var.environment
    Project     = local.project_name
  }
}

module "network" {
  source = "../../../../terraform/modules/network"

  name                      = "${local.name_prefix}-core"
  cidr_block                = local.cidr_block
  azs                       = local.azs
  public_subnet_cidrs       = local.public_subnet_cidrs
  private_app_subnet_cidrs  = local.private_app_subnet_cidrs
  private_data_subnet_cidrs = local.private_data_subnet_cidrs
  enable_flow_logs          = true
  flow_log_destination_arn  = aws_cloudwatch_log_group.flow_logs.arn
  tags                      = { Environment = var.environment, Project = local.project_name }
}

module "tgw" {
  source = "../../../../terraform/modules/tgw"

  name       = "${local.name_prefix}-tgw"
  vpc_id     = module.network.vpc_id
  subnet_ids = slice(module.network.private_app_subnet_ids, 0, 2)
  tags       = { Environment = var.environment, Project = local.project_name }
}

resource "aws_security_group" "endpoints" {
  name        = "${local.name_prefix}-endpoints"
  description = "Interface endpoint sg"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Environment = var.environment, Project = local.project_name }
}

locals {
  endpoint_services = [
    "com.amazonaws.${var.region}.secretsmanager",
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.logs",
    "com.amazonaws.${var.region}.ssm"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.endpoint_services)

  vpc_id              = module.network.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.network.private_app_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Environment = var.environment, Project = local.project_name }
}

module "eks" {
  source = "../../../../terraform/modules/eks"

  cluster_name       = "${local.name_prefix}-eks"
  kubernetes_version = "1.29"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_app_subnet_ids
  node_groups        = local.node_groups
  kms_key_arn        = aws_kms_key.general.arn
  enable_irsa        = true

  tags = { Environment = var.environment, Project = local.project_name }
}

module "security" {
  source = "../../../../terraform/modules/security"

  name   = "${local.name_prefix}-sec"
  region = var.region
  tags   = { Environment = var.environment, Project = local.project_name }
}

module "cognito" {
  source = "../../../../terraform/modules/cognito"

  project_name             = local.project_name
  environment              = var.environment
  domain_prefix            = var.cognito_domain_prefix
  dummy_user_email         = var.dummy_user_email
  dummy_user_temp_password = var.dummy_user_temp_password
  tags                     = { Environment = var.environment, Project = local.project_name }
}

module "ingress" {
  source = "../../../../terraform/modules/ingress"

  name              = "${local.name_prefix}-alb"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  certificate_arn   = module.dns.certificate_arn
  routes            = local.ingress_routes
  health_check_path = "/healthz"
  waf_arn           = module.security.waf_arn
  tags              = { Environment = var.environment, Project = local.project_name }
}

resource "aws_route53_record" "app" {
  zone_id = module.dns.zone_id
  name    = "app.${local.fqdn_prefix}"
  type    = "A"

  alias {
    name                   = module.ingress.alb_dns_name
    zone_id                = module.ingress.alb_zone_id
    evaluate_target_health = true
  }
}

module "iam" {
  source = "../../../../terraform/modules/iam"

  name                        = "terraform"
  environment                 = var.environment
  github_repositories         = var.github_repositories
  create_github_oidc_provider = var.create_github_oidc_provider
  github_oidc_provider_arn    = var.github_oidc_provider_arn
  tags                        = { Environment = var.environment, Project = local.project_name }
}

data "aws_iam_policy_document" "app_deployer_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.iam.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subjects
    }
  }
}

data "aws_iam_policy_document" "app_deployer" {
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:SetRepositoryPolicy",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EksDescribe"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${module.eks.cluster_name}"
    ]
  }

  statement {
    sid    = "SecretsRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.project_name}-${var.environment}*",
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project_name}/${var.environment}*"
    ]
  }

  statement {
    sid       = "KmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.general.arn]
  }
}

resource "aws_iam_role" "app_deployer" {
  name               = "${local.name_prefix}-app-deployer"
  assume_role_policy = data.aws_iam_policy_document.app_deployer_assume.json

  tags = {
    Environment = var.environment
    Project     = local.project_name
  }
}

resource "aws_iam_role_policy" "app_deployer" {
  name   = "${aws_iam_role.app_deployer.name}-inline"
  role   = aws_iam_role.app_deployer.id
  policy = data.aws_iam_policy_document.app_deployer.json
}

data "aws_iam_policy_document" "app_irsa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.cluster_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.cluster_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.cluster_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:ecommerce:*"]
    }
  }
}

data "aws_iam_policy_document" "app_irsa" {
  statement {
    sid    = "SecretsRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.project_name}-${var.environment}*",
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project_name}/${var.environment}*"
    ]
  }

  statement {
    sid       = "KmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.general.arn]
  }
}

resource "aws_iam_role" "app_irsa" {
  name               = "${local.name_prefix}-app-irsa"
  assume_role_policy = data.aws_iam_policy_document.app_irsa_assume.json

  tags = {
    Environment = var.environment
    Project     = local.project_name
  }
}

resource "aws_iam_role_policy" "app_irsa" {
  name   = "${aws_iam_role.app_irsa.name}-inline"
  role   = aws_iam_role.app_irsa.id
  policy = data.aws_iam_policy_document.app_irsa.json
}

