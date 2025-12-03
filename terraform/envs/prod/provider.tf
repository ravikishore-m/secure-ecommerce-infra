/** AWS provider for the application-layer prod environment. */
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

