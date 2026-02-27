module "vpc_default_configs" {
  source = "../.."
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
      #az_ids = ["use1-az1"]
    }
    nat_instance = {
      create = true
      ami_id = "ami-0ca984f09582cece2" #  ID of NatInstance Image imported by `docs/nat-instance-ami-setup.md` or console
      #az_ids = ["use1-az1","use1-az2"]
      #exclude_az_ids = ["use1-az2", "use1-az1"]
    }
    subnet_layers = [
      {
        name               = "edge"
        az_widerange       = 4
        netlength          = 8
        scope              = "public"
        nat_gw_scope       = "public"
        nat_instance_scope = "public"
      },
      {
        name                                         = "app"
        netlength                                    = 7
        netnum                                       = 2
        has_outbound_internet_access_via_natgw       = true
        has_outbound_internet_access_via_natinstance = true
      },
      {
        name      = "db"
        az_ids    = ["use1-az1", "use1-az3"]
        netnum    = 11
        netlength = 8
      },
      {
        name                          = "awssvc"
        netprefix                     = "10.0.16.0/20"
        netlength                     = 4
        network_acl_quarentine        = true # bloqueia acesso nas NACLs, mas deixa os servicos ligados
        network_acl_quarentine_az_ids = ["use1-az2"]
        network_acl_rules = [
          {
            action     = "deny"
            cidr_block = "0.0.0.0/0"
            egress     = true
            from_port  = 3306
            protocol   = "tcp"
            rule_no    = 4
            to_port    = 3306
          },
          {
            action     = "deny"
            cidr_block = "200.200.200.200/32"
            egress     = false
            from_port  = 80
            protocol   = "tcp"
            rule_no    = 10
            to_port    = 80
          }
        ]
      },
      {
        name         = "internal-lbs"
        az_widerange = 2
        cidr_block   = ["10.0.24.0/23", "10.0.26.0/23"]
        #routes = [
        #  {
        #    destination_cidr_block = ["8.8.8.8/32","8.8.4.4/32","8.8.2.2/32", "8.9.9.2/32"]
        #    target = "eni-0213f0458ae02a559"
        #  },
        #  {
        #    destination_cidr_block = ["200.200.200.200/32"]
        #    target = "eni-0213f0458ae02a559"
        #    az_ids = ["use1-az1"]
        #  }
        #]
      },
    ]
    #peering_connection = [
    #  {
    #    peer_vpc_id         = "vpc-022884eeb238a7a8e"
    #    cidr_blocks         = ["172.30.0.0/16","172.31.0.0/16"]
    #    route_tables_filter = { name = "tag:subnet_layer", values = ["app","internal-lbs"] }
    #  }
    #]
    vpc_endpoints = { # usado para sua vpc falar com serviços da amazon de forma privada
      s3 = {
        route_tables_filter = {
          name   = "tag:subnet_layer",
          values = ["app", "edge"]
        }
        service_type = "gateway"
      }
      rds = {
        subnet_filter = {
          name   = "tag:subnet_layer",
          values = ["awssvc"]
        }
        service_type = "interface"
      }
      # "com.amazonaws.vpce.us-east-1.vpce-svc-02bb719817b4acce2" = { # conectando em um load balancer
      #   #az_ids = ["use1-az2"]
      #   exclude_az_ids = ["use1-az1","use1-az3"]
      #   service_type = "endpointservice" # 
      #   #subnet_filter = {
      #   #  name = "tag:subnet_layer",
      #   #  values = ["awssvc"] 
      #   #} 
      # }
    }
  }
}


module "vpc_noconfig" {
  source = "../.."
  vpc_config = {
    vpc = {
      create = false
    }
  }
}



module "vpc_peer_connect_accept" {
  source = "../.."
  vpc_config = {
    vpc = {
      create = false
      vpc_id = "vpc-022884eeb238a7a8e"
    }
    #peering_connection = [
    #  {
    #    cidr_blocks               = ["172.30.0.0/16"]
    #    route_tables_filter       = { name = "tag:subnet_layer", values = ["app"] }
    #    vpc_peering_connection_id = "pcx-092e35abf7fbba4fa"
    #  }
    #]
  }
}

output "name" {
  value = module.vpc_default_configs.teste
}
