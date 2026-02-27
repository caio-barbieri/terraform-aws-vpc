module "vpc" {
  source = "../.."

  vpc_config = {
    vpc = {
      cidr_block = "10.0.0.0/16"
    }
    global = {
      az = {
        exclude_zone_ids = ["use1-az5"]
      }
      igw = {
        create = false
      }
      tags = {
        stack         = "demo-marcus"
        env           = "production"
        "opsteam:env" = "production"
      }
    }
    #nat_gateway = {
    #  create = true
    #}
    # nat_instance = {
    #   create = true
    #   ami_id = "ami-0ca984f09582cece2" #  ID of NatInstance Image imported by `docs/nat-instance-ami-setup.md` or console 
    # }
    subnet_layers = [
      {
        name      = "private"
        netlength = 8
        netnum    = 3
        scope     = "private"
        routes = [
          {
            #            az_ids                 = ["use1-az1"] 
            destination_cidr_block = ["0.0.0.0/0"]
            target                 = "tgw-0d470a797d274d614"
          }
        ]
      },
      {
        name      = "db"
        netlength = 8
        netnum    = 32
        scope     = "private"
      }
    ]
    transit_gateway = {
      "TG-INTERNAT" = {
      }
    }
  }
}
