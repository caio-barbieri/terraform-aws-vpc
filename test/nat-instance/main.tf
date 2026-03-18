module "vpc" {
  source = "../.."

  vpc_config = {
    vpc = {
      cidr_block = "10.100.0.0/16"
    }
    global = {
      tags = {
        "Name"          = "roadcard_security_vpc"
        "cloud_partner" = "opsteam"
        "managed_by"    = "terraform"
        "project_id"    = "infra_vpc"
        "stack"         = "security"
      }
    }
    nat_gateway = {
      create = false
    }
    nat_instance = {
      create               = true
      ami_id               = "ami-01609434bc459a2e7"
      key_name             = "nat-instance-temp"
      iam_instance_profile = "EC2-SSM-Profile"
      az_widerange         = 1
      instance_tags = {
        "Name" = "nat-instance-security-vpc"
      }
    }
    vpc_endpoints = {} # Explicitly no VPC endpoints
    subnet_layers = [
      {
        name                                         = "public"
        cidr_block                                   = ["10.100.0.0/20", "10.100.16.0/20", "10.100.32.0/20"]
        scope                                        = "public"
        nat_instance_scope                           = "public"
        map_public_ip_on_launch                      = true
        has_outbound_internet_access_via_natgw       = false
        has_outbound_internet_access_via_natinstance = false
      },
      {
        name                                         = "private"
        cidr_block                                   = ["10.100.128.0/20", "10.100.144.0/20", "10.100.160.0/20"]
        scope                                        = "private"
        has_outbound_internet_access_via_natgw       = false
        has_outbound_internet_access_via_natinstance = true
      }
    ]
  }
}
