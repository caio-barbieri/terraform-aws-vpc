terraform {
  backend "s3" {
    bucket = "roadcard-security-terraform-state"
    key    = "infrastructure/sa-east-1/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = "sa-east-1"
  profile = "CL037-SEC"
}
