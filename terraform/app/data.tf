data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket   = "cesar-stylesage-terraform"
    key      = "base/${terraform.workspace}/terraform.tfstate"
    region   = "eu-west-1"
  }
}
