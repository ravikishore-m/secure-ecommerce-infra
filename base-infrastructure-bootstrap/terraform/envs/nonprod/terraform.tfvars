owner                       = "platform-team"
region                      = "us-east-1"
assume_role_arn             = "arn:aws:iam::111111111111:role/SharedServicesTerraform"
alert_emails                = ["nonprod-alerts@ecommerce.internal"]
github_repositories         = ["cigna/ecommerce-infra"]
create_github_oidc_provider = false
github_oidc_provider_arn    = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
root_domain                 = "demo.ecommerce-example.com"
create_hosted_zone          = true
cognito_domain_prefix       = "ecom-demo"
dummy_user_email            = "demo@nonprod.ecommerce"
dummy_user_temp_password    = "TempPassword123!"

