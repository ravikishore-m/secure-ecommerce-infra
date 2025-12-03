terraform {
  backend "s3" {
    bucket     = "ecommerce-platform-tfstate"
    key        = "base/nonprod/terraform.tfstate"
    region     = "us-east-1"
    encrypt    = true
    kms_key_id = "alias/ecommerce-platform/tf-state"
  }
}
