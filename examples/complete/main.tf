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
  description = "AWS Region where the example resources will be planned"
  type        = string
  default     = "us-east-1"
}

module "vpc" {
  source = "../.."

  vpc_config = {
    vpc = {
      cidr_block = "10.42.0.0/16"
    }

    global = {
      tags = {
        Environment = "sandbox"
        Project     = "terraform-aws-vpc"
        Owner       = "platform"
        ManagedBy   = "Terraform"
      }
    }

    flow_logs = {
      create                       = true
      cloudwatch_retention_in_days = 30
    }

    ipv6 = {
      enabled = true
    }

    nat_gateway = {
      create       = true
      az_widerange = 2
    }

    subnet_layers = [
      {
        name                    = "public"
        scope                   = "public"
        az_widerange            = 2
        cidr_block              = ["10.42.0.0/24", "10.42.1.0/24"]
        map_public_ip_on_launch = true
      },
      {
        name                                   = "private"
        az_widerange                           = 2
        cidr_block                             = ["10.42.10.0/24", "10.42.11.0/24"]
        has_outbound_internet_access_via_natgw = true
      }
    ]

    transit_gateway = {
      core = {
        create = true

        vpc_attachment = {
          create             = true
          subnet_layer_names = ["private"]
          ipv6_support       = "enable"
        }

        transit_gateway_routes = {
          local_vpc_ipv4 = {
            destination_cidr_block = "10.42.0.0/16"
          }
        }
      }
    }
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ipv6_cidr_block" {
  value = module.vpc.ipv6_cidr_block
}

output "transit_gateway_vpc_attachment_ids" {
  value = module.vpc.transit_gateway_vpc_attachment_ids
}

output "vpc_flow_log_id" {
  value = module.vpc.vpc_flow_log_id
}
