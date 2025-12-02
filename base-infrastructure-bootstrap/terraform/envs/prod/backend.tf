terraform {
  backend "s3" {
    bucket         = "ecommerce-platform-tfstate"
    key            = "base/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ecommerce-platform-tf-locks"
  }
}

