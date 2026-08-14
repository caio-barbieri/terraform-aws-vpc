terraform {
  required_version = ">= 1.3.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS Region where the example VPC will be created"
  type        = string
  default     = "us-east-1"
}

module "vpc" {
  source = "../.."

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }

    global = {
      tags = {
        Name        = "example"
        Environment = "development"
        Project     = "terraform-aws-vpc"
        Owner       = "platform"
      }
    }

    subnet_layers = [
      {
        name         = "public"
        scope        = "public"
        az_widerange = 2
        cidr_block   = ["10.0.0.0/24", "10.0.1.0/24"]
      },
      {
        name         = "private"
        az_widerange = 2
        cidr_block   = ["10.0.10.0/24", "10.0.11.0/24"]
      }
    ]
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
