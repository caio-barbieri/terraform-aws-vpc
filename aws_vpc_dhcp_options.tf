#
#
#
resource "aws_vpc_dhcp_options" "dhcp_options" {
  for_each = var.vpc_config["vpc"]["create"] ? tomap(
    {
      "vpc" = merge(var.vpc_config, aws_vpc.vpc["vpc"])
    }
  ) : {}

  domain_name          = coalesce(each.value["dhcp_options"]["domain_name"], local.default_dhcp_domain_name)
  domain_name_servers  = each.value["dhcp_options"]["domain_name_servers"]
  ntp_servers          = each.value["dhcp_options"]["ntp_servers"]
  netbios_name_servers = each.value["dhcp_options"]["netbios_name_servers"]
  netbios_node_type    = each.value["dhcp_options"]["netbios_node_type"]
  tags = merge(
    var.vpc_config["dhcp_options"]["tags"],
    local.common_tags,
    tomap(
      {
        "Name" = upper(
          format(
            "dhcp-vpc-%s", each.value["tags"]["Name"]
          )
        )
        "opsteam:ParentObject"     = each.value["id"]
        "opsteam:ParentObjectArn"  = each.value["arn"]
        "opsteam:ParentObjectType" = "VPC"
      }
    ),
  )
}

#
#
#
resource "aws_vpc_dhcp_options_association" "dhcp_options" {
  for_each = var.vpc_config["vpc"]["create"] ? tomap(
    {
      "vpc" = merge(var.vpc_config, aws_vpc.vpc["vpc"])
    }
  ) : {}
  vpc_id          = try(each.value["id"], each.value["vpc_id"])
  dhcp_options_id = aws_vpc_dhcp_options.dhcp_options["vpc"].id
}
