owner                       = "Machiraju Ravikishore"
region                      = "us-east-1"
assume_role_arn             = "arn:aws:iam::111111111111:role/SharedServicesTerraform"
alert_emails                = ["nonprod-alerts@ecommerce.internal"]
github_repositories         = ["your-github-user/secure-ecommerce-infra"]
create_github_oidc_provider = false
github_oidc_provider_arn    = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"

