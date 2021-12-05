terraform {
  backend "s3" {
    bucket               = "cesar-stylesage-terraform"
    workspace_key_prefix = "iotd"
    key                  = "terraform.tfstate"
    region               = "eu-west-1"
    encrypt              = true
  }
}
