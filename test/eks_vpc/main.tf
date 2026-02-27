module "vpc" {
  source = "../.."
  # source = "git@github.com:opsteamhub/terraform-aws-vpc.git"

  vpc_config = {
    vpc = {
      cidr_block = "10.200.0.0/16"
      tags = {
        "ops.team/eks/cluster/opsteam-eks-cluster" = "true"
      }
    }
    global = {
      az = {
        exclude_zone_ids = ["use1-az3"]
      }
      tags = {
        stack                                              = "opsteam-eks-cluster"
        env                                                = "production"
        "opsteam:id"                                       = "0001"
        "opsteam:clientid"                                 = "0000"
        "opsteam:env"                                      = "production"
        "kubernetes.io/cluster/opsteam-eks-cluster-718249" = "shared"

      }
    }
    nat_instance = {
      create = true
      ami_id = "ami-0ca984f09582cece2" #  ID of NatInstance Image imported by `docs/nat-instance-ami-setup.md` or console 
    }
    subnet_layers = [
      {
        name                                         = "app"
        netlength                                    = 6
        az_widerange                                 = 3
        netnum                                       = "3"
        scope                                        = "private"
        has_outbound_internet_access_via_natinstance = true
        tags = {
          tier                                                          = "private"
          "kubernetes.io/role/internal-elb"                             = 1
          "ops.team/eks/cluster/opsteam-eks-cluster/node_group/default" = "true" #node group
          "ops.team/eks/cluster/opsteam-eks-cluster"                    = "true" #control plane
        }
      },
      {
        name               = "edge"
        netlength          = 6
        az_widerange       = 3
        scope              = "public"
        nat_instance_scope = "public"
        tags = {
          tier                         = "public"
          "kubernetes.io/cluster/node" = "shared"
          "sub"                        = "pub"
          "kubernetes.io/role/elb"     = "1"
        }
      }
    ],
  }
}
