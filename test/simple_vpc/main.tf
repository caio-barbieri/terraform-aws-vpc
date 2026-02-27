module "vpc" {
  source = "../.."
  # source = "git@github.com:opsteamhub/terraform-aws-vpc.git"

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }
    global = {
      az = {
        exclude_zone_ids = ["use1-az5"]
      }
      tags = {
        stack              = "eks-opsteam"
        env                = "production"
        "opsteam:id"       = "0001"
        "opsteam:clientid" = "0001"
        "opsteam:env"      = "production"
      }
    }
    nat_gateway = {
      create = false
    }
    # nat_instance = {
    #   create = true
    #   ami_id = "ami-0ca984f09582cece2" #  ID of NatInstance Image imported by `docs/nat-instance-ami-setup.md` or console 
    # }
    subnet_layers = [
      {
        name                                         = "public"
        cidr_block                                   = ["10.0.1.0/24"]
        scope                                        = "public"
        has_outbound_internet_access_via_natgw       = true
        has_outbound_internet_access_via_natinstance = true
      },
      {
        name                                         = "private"
        cidr_block                                   = ["10.0.2.0/24"]
        scope                                        = "private"
        has_outbound_internet_access_via_natgw       = true
        has_outbound_internet_access_via_natinstance = true
      }
    ]
  }
}
