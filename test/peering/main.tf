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
    ],
    peering_connection = [
      {
        peer_owner_id = "11111111111"     #ID da conta de destino
        peer_vpc_id   = "vpc-00000000000" #VPC de destino
        #peer_region   = "us-east-1"
        cidr_blocks = ["172.27.18.0/24"] #CIDR da conta de destino
        #requester = {
        #  allow_remote_vpc_dns_resolution = true
        #  }
        accepter = {
          allow_remote_vpc_dns_resolution = true
        }
        route_tables_filter = {
          name   = "tag:subnet_layer"
          values = ["private"] #Nome da VPC que foi criada pelo módulo
        }
      }
    ]
  }
}
