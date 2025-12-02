locals {
  pool_name = "${var.project_name}-${var.environment}-users"
}

resource "aws_cognito_user_pool" "this" {
  name = local.pool_name

  alias_attributes = ["email"]

  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.domain_prefix}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${local.pool_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  explicit_auth_flows                  = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = ["https://localhost/callback"]
  logout_urls                          = ["https://localhost/logout"]
  refresh_token_validity               = 30
  access_token_validity                = 1
  id_token_validity                    = 1
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Platform administrators"
}

resource "aws_cognito_user_group" "developers" {
  name         = "developers"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Developer persona"
}

resource "aws_cognito_user" "demo" {
  user_pool_id = aws_cognito_user_pool.this.id
  username     = var.dummy_user_email
  attributes = {
    email = var.dummy_user_email
  }
  temporary_password = var.dummy_user_temp_password
  message_action     = "SUPPRESS"
}

resource "aws_cognito_user_in_group" "demo_dev" {
  user_pool_id = aws_cognito_user_pool.this.id
  username     = aws_cognito_user.demo.username
  group_name   = aws_cognito_user_group.developers.name
}

