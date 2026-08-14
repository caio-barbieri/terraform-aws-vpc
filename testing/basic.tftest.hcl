# Provider mocking requires Terraform 1.7 or newer.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-0123456789abcdef0"
      arn        = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-0123456789abcdef0"
      cidr_block = "10.6.0.0/16"
    }
  }

  mock_data "aws_vpc_endpoint_service" {
    defaults = {
      service_name = "com.amazonaws.us-east-1.s3"
      service_type = "Gateway"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      latest_version = 1
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/vpc/flow-logs/test"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/vpc-flow-logs"
      id  = "vpc-flow-logs"
    }
  }

  mock_resource "aws_network_interface" {
    defaults = {
      id = "eni-0123456789abcdef0"
    }
  }

  mock_resource "aws_nat_gateway" {
    defaults = {
      id = "nat-0123456789abcdef0"
    }
  }

  mock_resource "aws_vpc_ipv6_cidr_block_association" {
    defaults = {
      id              = "vpc-cidr-assoc-0123456789abcdef0"
      ipv6_cidr_block = "2600:1f18:abcd:1200::/56"
    }
  }

  mock_resource "aws_ec2_transit_gateway" {
    defaults = {
      id                                 = "tgw-0123456789abcdef0"
      association_default_route_table_id = "tgw-rtb-0123456789abcdef0"
    }
  }

  mock_resource "aws_ec2_transit_gateway_vpc_attachment" {
    defaults = {
      id = "tgw-attach-0123456789abcdef0"
    }
  }
}

run "creates_a_minimal_vpc_without_hidden_tag_requirements" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.0.0.0/16"
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

  assert {
    condition     = aws_vpc.vpc["vpc"].tags["Name"] == "VPC"
    error_message = "The minimal configuration must receive a deterministic default Name tag."
  }

  assert {
    condition     = length(aws_subnet.subnets) == 4
    error_message = "The module must create one public and one private subnet in each selected AZ."
  }

  assert {
    condition     = length(output.public_subnet_ids) == 2 && length(output.private_subnet_ids) == 2
    error_message = "Public and private subnet outputs must expose the created subnets by scope."
  }
}

run "creates_gateway_and_interface_endpoints_with_simple_defaults" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.1.0.0/16"
      }

      global = {
        tags = {
          Name = "endpoints"
        }
      }

      subnet_layers = [
        {
          name         = "private"
          az_widerange = 1
          cidr_block   = ["10.1.0.0/24"]
        }
      ]

      vpc_endpoints = {
        s3 = {
          service_type = "Gateway"
        }
        ec2 = {
          service_type = "Interface"
          subnet_ids   = ["subnet-0123456789abcdef0"]
        }
      }
    }
  }

  assert {
    condition     = length(aws_vpc_endpoint.vpc_endpoint_gw) == 1
    error_message = "A Gateway endpoint must use the route tables created by the module when no filter is provided."
  }

  assert {
    condition     = one(values(aws_vpc_endpoint.vpc_endpoint_interface)).subnet_ids == toset(["subnet-0123456789abcdef0"])
    error_message = "An Interface endpoint must accept explicit subnet IDs without an AWS subnet lookup."
  }
}

run "uses_the_regional_default_dhcp_domain" {
  command = apply

  override_data {
    target = data.aws_region.session
    values = {
      region = "sa-east-1"
    }
  }

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.2.0.0/16"
      }
    }
  }

  assert {
    condition     = aws_vpc_dhcp_options.dhcp_options["vpc"].domain_name == "sa-east-1.compute.internal"
    error_message = "Regions outside us-east-1 must use the regional EC2 DHCP domain by default."
  }
}

run "creates_a_hardened_nat_instance_from_a_public_subnet" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.3.0.0/16"
      }

      nat_instance = {
        create                    = true
        ami_id                    = "ami-0123456789abcdef0"
        az_widerange              = 1
        iam_instance_profile_name = "nat-instance-ssm"
      }

      subnet_layers = [
        {
          name         = "public"
          scope        = "public"
          az_widerange = 1
          cidr_block   = ["10.3.0.0/24"]
        },
        {
          name                                         = "private"
          az_widerange                                 = 1
          cidr_block                                   = ["10.3.10.0/24"]
          has_outbound_internet_access_via_natinstance = true
        }
      ]
    }
  }

  assert {
    condition = (
      length(one(one(values(aws_security_group.natinstance_sg)).ingress).cidr_blocks) == 1 &&
      contains(one(one(values(aws_security_group.natinstance_sg)).ingress).cidr_blocks, "10.3.0.0/16")
    )
    error_message = "The NAT instance security group must accept forwarded traffic only from the VPC CIDR."
  }

  assert {
    condition     = one(values(aws_launch_template.natinstance_lt)).metadata_options[0].http_tokens == "required"
    error_message = "NAT instances must require IMDSv2 tokens."
  }

  assert {
    condition     = length(aws_route.r_natinstance) == 1
    error_message = "A private subnet marked for NAT instance egress must receive a route."
  }
}

run "creates_a_nat_gateway_from_a_public_subnet" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.4.0.0/16"
      }

      nat_gateway = {
        create       = true
        az_widerange = 1
      }

      subnet_layers = [
        {
          name         = "public"
          scope        = "public"
          az_widerange = 1
          cidr_block   = ["10.4.0.0/24"]
        },
        {
          name                                   = "private"
          az_widerange                           = 1
          cidr_block                             = ["10.4.10.0/24"]
          has_outbound_internet_access_via_natgw = true
        }
      ]
    }
  }

  assert {
    condition     = length(aws_nat_gateway.nat-gw) == 1
    error_message = "A public subnet must be a NAT Gateway candidate without requiring nat_gw_scope duplication."
  }

  assert {
    condition     = length(aws_route.r_natgw) == 1
    error_message = "A private subnet marked for NAT Gateway egress must receive a route."
  }
}

run "creates_a_security_group_with_optional_rule_lists" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.5.0.0/16"
      }

      security_groups = [
        {
          name        = "app"
          name_prefix = "app-"
          ingress = [
            {
              from_port   = 443
              to_port     = 443
              protocol    = "tcp"
              cidr_blocks = ["10.5.0.0/16"]
            }
          ]
        }
      ]
    }
  }

  assert {
    condition     = aws_security_group.security_group["app"].name_prefix == "app-"
    error_message = "name_prefix must be passed to the AWS Security Group resource when configured."
  }

  assert {
    condition     = length(aws_security_group_rule.ingress_rules) == 1 && length(aws_security_group_rule.egress_rules) == 0
    error_message = "Omitting an optional Security Group rule list must create no rules instead of failing evaluation."
  }
}

run "uses_the_existing_vpc_cidr_for_interface_endpoints" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        create = false
        vpc_id = "vpc-0123456789abcdef0"
      }

      vpc_endpoints = {
        ec2 = {
          service_type = "Interface"
          subnet_ids   = ["subnet-0123456789abcdef0"]
        }
      }
    }
  }

  assert {
    condition = contains(
      one(one(values(aws_security_group.sg-vpce-interface)).ingress).cidr_blocks,
      "10.6.0.0/16"
    )
    error_message = "An Interface endpoint in an existing VPC must discover and allow that VPC's CIDR."
  }
}

run "creates_cloudwatch_vpc_flow_logs_with_managed_delivery_permissions" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.7.0.0/16"
      }

      flow_logs = {
        create                       = true
        cloudwatch_retention_in_days = 30
      }
    }
  }

  assert {
    condition     = length(aws_flow_log.vpc) == 1 && one(values(aws_flow_log.vpc)).traffic_type == "ALL"
    error_message = "Flow Logs must be created for all VPC traffic when enabled with defaults."
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_group.vpc_flow_logs) == 1 &&
      one(values(aws_cloudwatch_log_group.vpc_flow_logs)).retention_in_days == 30 &&
      length(aws_iam_role.vpc_flow_logs) == 1
    )
    error_message = "CloudWatch Flow Logs must create a retained log group and a scoped delivery role by default."
  }
}

run "creates_dual_stack_subnets_and_ipv6_egress_routes" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.8.0.0/16"
      }

      ipv6 = {
        enabled = true
      }

      subnet_layers = [
        {
          name         = "public"
          scope        = "public"
          az_widerange = 1
          cidr_block   = ["10.8.0.0/24"]
        },
        {
          name         = "private"
          az_widerange = 1
          cidr_block   = ["10.8.10.0/24"]
        }
      ]
    }
  }

  assert {
    condition = (
      aws_subnet.subnets["public-use1-az1"].ipv6_cidr_block == "2600:1f18:abcd:1200::/64" &&
      aws_subnet.subnets["private-use1-az1"].ipv6_cidr_block == "2600:1f18:abcd:1201::/64"
    )
    error_message = "Dual-stack subnets must receive deterministic, non-overlapping /64 CIDRs."
  }

  assert {
    condition = (
      length(aws_route.ipv6_public) == 1 &&
      length(aws_route.ipv6_private) == 1 &&
      length(aws_egress_only_internet_gateway.ipv6) == 1
    )
    error_message = "Public and private IPv6 subnets must receive IGW and egress-only IGW routes respectively."
  }
}

run "creates_transit_gateway_attachment_and_both_route_directions" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.9.0.0/16"
      }

      subnet_layers = [
        {
          name         = "private"
          az_widerange = 2
          cidr_block   = ["10.9.0.0/24", "10.9.1.0/24"]
        }
      ]

      transit_gateway = {
        core = {
          create = true
          vpc_attachment = {
            create = true
          }
          transit_gateway_routes = {
            local_vpc = {
              destination_cidr_block = "10.9.0.0/16"
            }
          }
          vpc_routes = {
            shared_services = {
              destination_cidr_block = "10.100.0.0/16"
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_ec2_transit_gateway_vpc_attachment.vpc_attachment) == 1 &&
      length(one(values(aws_ec2_transit_gateway_vpc_attachment.vpc_attachment)).subnet_ids) == 2
    )
    error_message = "The Transit Gateway attachment must use the configured subnet layer across AZs."
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.route) == 1 && length(aws_route.transit_gateway) == 2
    error_message = "Transit Gateway routing must configure the TGW route table and each selected VPC route table."
  }
}

run "maps_nat_instance_routes_to_the_same_availability_zone" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.10.0.0/16"
      }

      nat_instance = {
        create       = true
        ami_id       = "ami-0123456789abcdef0"
        az_widerange = 2
      }

      subnet_layers = [
        {
          name         = "public"
          scope        = "public"
          az_widerange = 2
          cidr_block   = ["10.10.0.0/24", "10.10.1.0/24"]
        },
        {
          name                                         = "private"
          az_widerange                                 = 2
          cidr_block                                   = ["10.10.10.0/24", "10.10.11.0/24"]
          has_outbound_internet_access_via_natinstance = true
        }
      ]
    }
  }

  assert {
    condition = (
      local.nat_instance_subnet_by_az["use1-az1"] == "public-use1-az1" &&
      local.nat_instance_subnet_by_az["use1-az2"] == "public-use1-az2" &&
      length(aws_route.r_natinstance) == 2
    )
    error_message = "Private subnet routes must prefer the NAT instance in the same Availability Zone."
  }
}

run "rejects_existing_vpc_mode_without_a_vpc_id" {
  command = plan

  variables {
    vpc_config = {
      vpc = {
        create = false
      }
    }
  }

  expect_failures = [var.vpc_config]
}

run "derives_non_overlapping_subnets_without_manual_cidrs" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.20.0.0/16"
      }

      subnet_layers = [
        {
          name         = "public"
          scope        = "public"
          az_widerange = 2
        },
        {
          name         = "private"
          az_widerange = 2
        }
      ]
    }
  }

  assert {
    condition = (
      aws_subnet.subnets["public-use1-az1"].cidr_block == "10.20.0.0/24" &&
      aws_subnet.subnets["public-use1-az2"].cidr_block == "10.20.1.0/24" &&
      aws_subnet.subnets["private-use1-az1"].cidr_block == "10.20.2.0/24" &&
      aws_subnet.subnets["private-use1-az2"].cidr_block == "10.20.3.0/24"
    )
    error_message = "Subnet layers without explicit CIDRs must receive deterministic, non-overlapping CIDRs."
  }
}

run "skips_dependent_resources_for_disabled_subnet_layers" {
  command = apply

  variables {
    vpc_config = {
      vpc = {
        cidr_block = "10.21.0.0/16"
      }

      ipv6 = {
        enabled = true
      }

      subnet_layers = [
        {
          create       = false
          ipv6_enabled = true
          name         = "reserved"
          az_widerange = 2
        }
      ]
    }
  }

  assert {
    condition = (
      length(aws_subnet.subnets) == 0 &&
      length(aws_route_table.rt) == 0 &&
      length(aws_network_acl.nacl) == 0 &&
      length(aws_route.ipv6_private) == 0 &&
      length(aws_egress_only_internet_gateway.ipv6) == 0
    )
    error_message = "A disabled subnet layer must not create dependent networking resources."
  }
}
