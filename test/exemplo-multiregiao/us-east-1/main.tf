module "vpc" {
  source = "../../.."

  vpc_config = {
    vpc = {
      cidr_block = "10.100.0.0/16"
    }
    global = {
      tags = {
        Name               = "roadcard-security-vpc"
        Environment        = "security"
        ManagedBy          = "Terraform"
        stack              = "security"
        "opsteam:clientid" = "CL037"
      }
    }
    nat_gateway = {
      create = false
    }
    nat_instance = {
      create = false
    }
    subnet_layers = [
      {
        name                             = "public"
        cidr_block                       = ["10.100.0.0/20", "10.100.16.0/20", "10.100.32.0/20"]
        scope                            = "public"
        map_public_ip_on_launch          = true
        has_outbound_internet_access_via_natgw       = false
        has_outbound_internet_access_via_natinstance = false
      },
      {
        name                             = "private"
        cidr_block                       = ["10.100.128.0/20", "10.100.144.0/20", "10.100.160.0/20"]
        scope                            = "private"
        has_outbound_internet_access_via_natgw       = false
        has_outbound_internet_access_via_natinstance = false
      }
    ]
  }
}
