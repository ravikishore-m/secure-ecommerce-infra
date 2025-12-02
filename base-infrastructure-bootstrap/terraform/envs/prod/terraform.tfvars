owner                       = "Machiraju Ravikishore"
region                      = "us-east-1"
assume_role_arn             = "arn:aws:iam::222222222222:role/ProdTerraform"
alert_emails                = ["prod-oncall@ecommerce.internal"]
github_repositories         = ["your-github-user/secure-ecommerce-infra"]
create_github_oidc_provider = false
github_oidc_provider_arn    = "arn:aws:iam::222222222222:oidc-provider/token.actions.githubusercontent.com"
root_domain                 = "prod.ecommerce-example.com"
create_hosted_zone          = true
cognito_domain_prefix       = "ecom-prod"
dummy_user_email            = "demo@prod.ecommerce"
dummy_user_temp_password    = "ProdPassword123!"

