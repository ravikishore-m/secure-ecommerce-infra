owner                       = "platform-team"
region                      = "us-east-1"
assume_role_arn             = "arn:aws:iam::222222222222:role/ProdTerraform"
alert_emails                = ["prod-oncall@ecommerce.internal"]
github_repositories         = ["cigna/ecommerce-infra"]
create_github_oidc_provider = false
github_oidc_provider_arn    = "arn:aws:iam::222222222222:oidc-provider/token.actions.githubusercontent.com"

