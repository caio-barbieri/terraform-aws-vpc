#
# Retrieve data from AWS API to get all the available Availability 
# Zones for the region.
#
data "aws_availability_zones" "region_azs" {
  state            = try(var.vpc_config["global"]["az"]["state"], null)
  exclude_zone_ids = try(var.vpc_config["global"]["az"]["exclude_zone_ids"], null)
}



locals {

  #
  # Process the subnet layers defined by the developers/engineer/architect
  # to spread the Subnets between different AZs configurations, besides
  # handle the CIDR block definition based in the user inputs. 
  #
  subnets = [
    for layer_index, y in coalesce(var.vpc_config["subnet_layers"], []) :
    {
      for w, z in coalesce(
        y["az_ids"],
        slice(
          sort(
            data.aws_availability_zones.region_azs.zone_ids
          ),
          0,
          y["az_widerange"]
        )
      ) :
      format("%s-%s", y["name"], z) => merge(
        y,
        {
          "az_id" : z,
          "cidr_block" : try(
            element(y["cidr_block"], w),
            cidrsubnet(
              coalesce(
                y["netprefix"],
                try(
                  aws_vpc.vpc["vpc"].cidr_block,
                  var.vpc_config["vpc"]["cidr_block"]
                )
              ),
              y["netlength"],
              coalesce(
                y["netnum"],
                sum([
                  for previous_index, previous_layer in var.vpc_config.subnet_layers :
                  previous_index < layer_index ? (
                    previous_layer.az_ids != null ? length(previous_layer.az_ids) : previous_layer.az_widerange
                  ) : 0
                ])
              ) + w
            )
          )
          "ipv6_enabled" : local.ipv6_enabled && y["ipv6_enabled"],
          "ipv6_cidr_block" : local.ipv6_enabled && y["ipv6_enabled"] ? try(
            element(y["ipv6_cidr_block"], w),
            cidrsubnet(
              local.vpc_ipv6_cidr_block,
              64 - tonumber(element(split("/", local.vpc_ipv6_cidr_block), 1)),
              sum([
                for previous_index, previous_layer in var.vpc_config.subnet_layers :
                previous_index < layer_index ? (
                  previous_layer.az_ids != null ? length(previous_layer.az_ids) : previous_layer.az_widerange
                ) : 0
              ]) + w
            )
          ) : null,
          "subnet_layer_ordered_id" : w,
          "subnet_name" : format("%s-%s", y["name"], z),
          "vpc_id" : try(
            aws_vpc.vpc["vpc"].id,
            var.vpc_config["vpc"]["vpc_id"]
          )
        }
      )
    }
  ]

  map_of_subnets = {
    for k, v in zipmap(
      flatten(
        [for x in local.subnets :
          keys(x)
        ]
      ),
      flatten(
        [for x in local.subnets :
          values(x)
        ]
      )
    ) :
    k => v
  }

}

#
# Deploy subnets
#
resource "aws_subnet" "subnets" {

  for_each = { for k, v in
    zipmap(
      flatten(
        [for x in local.subnets :
          keys(x)
        ]
      ),
      flatten(
        [for x in local.subnets :
          values(x)
        ]
      )
    ) :
    k => v if v["create"] == true
  }

  availability_zone_id                           = each.value["az_id"]
  assign_ipv6_address_on_creation                = each.value["ipv6_enabled"] ? each.value["assign_ipv6_address_on_creation"] : false
  cidr_block                                     = each.value["cidr_block"]
  enable_dns64                                   = each.value["ipv6_enabled"] ? each.value["enable_dns64"] : false
  enable_resource_name_dns_a_record_on_launch    = each.value["enable_resource_name_dns_a_record_on_launch"]
  enable_resource_name_dns_aaaa_record_on_launch = each.value["ipv6_enabled"] ? each.value["enable_resource_name_dns_aaaa_record_on_launch"] : false
  ipv6_cidr_block                                = each.value["ipv6_cidr_block"]
  map_public_ip_on_launch                        = each.value["map_public_ip_on_launch"]
  private_dns_hostname_type_on_launch            = each.value["private_dns_hostname_type_on_launch"]
  vpc_id                                         = each.value["vpc_id"]
  tags = merge(
    local.common_tags,
    tomap(
      {
        "has_outbound_internet_access_via_natgw"       = each.value["has_outbound_internet_access_via_natgw"]
        "has_outbound_internet_access_via_natinstance" = each.value["has_outbound_internet_access_via_natinstance"]
        "Name"                                         = each.key
        "nat_gw_scope"                                 = each.value["nat_gw_scope"]
        "opsteam:ParentObject"                         = each.value["vpc_id"]
        "opsteam:ParentObjectArn"                      = try(each.value["arn"], null)
        "opsteam:ParentObjectType"                     = "VPC"
        "scope"                                        = each.value["scope"]
        "subnet_layer_unit"                            = each.key
        "subnet_layer"                                 = each.value["name"]
      }
    ),
    each.value["tags"]
  )
}

###########################################################################################################################
###########################################################################################################################
###########################################################################################################################

#
# Deploy Route Table per Subnet
#
resource "aws_route_table" "rt" {

  for_each = aws_subnet.subnets

  vpc_id = each.value["tags"]["opsteam:ParentObject"]

  tags = merge(
    each.value["tags"],
    tomap(
      {
        "Name"                     = each.key
        "opsteam:ParentObject"     = each.value["id"]
        "opsteam:ParentObjectArn"  = each.value["arn"]
        "opsteam:ParentObjectType" = "Subnet"
      }
    ),
  )
}

#
# RouteTable Association
#
resource "aws_route_table_association" "rta" {

  for_each = aws_route_table.rt

  subnet_id      = each.value["tags"]["opsteam:ParentObject"]
  route_table_id = each.value["id"]
}

#
#
#


###########################################################################################################################
###########################################################################################################################
###########################################################################################################################

#
# Deploy Managed Prefix List to handle the Adhoc Routes
#
resource "aws_ec2_managed_prefix_list" "managed_prefixlist_adhoc_route" {

  for_each = zipmap(
    flatten(
      [for x in coalesce(var.vpc_config["subnet_layers"], []) :
        [
          for y, z in coalesce(x["routes"], []) :
          format("%s|%s", x["name"], y)
        ] if x["create"] && x["routes"] != null
      ]
    ),
    flatten(
      [for x in coalesce(var.vpc_config["subnet_layers"], []) :
        [
          for y, z in coalesce(x["routes"], []) :
          format("%s|%s|%s|%s", x["name"], y, join(",", element(x["routes"], y)["destination_cidr_block"]), element(x["routes"], y)["target"])
        ] if x["create"] && x["routes"] != null
      ]
    )
  )

  name           = upper(format("prefixlist-adhoc-route-%s", each.key))
  address_family = "IPv4"
  max_entries    = length(split(",", element(split("|", each.value), 2)))


  dynamic "entry" {
    for_each = split(",", element(split("|", each.value), 2))

    content {
      cidr = entry.value
    }
  }

  tags = merge(
    local.common_tags,
    {
      "Name" = upper(format("prefixlist-internet-%s", each.key))
    }
  )

}

#
# Deploy Adhoc Routes 
#
resource "aws_route" "r_adhoc" {

  for_each = zipmap(
    flatten(
      [
        for k, v in
        flatten(
          [for x in local.subnets :
            values(x)
          ]
        ) :
        [
          for y, z in coalesce(
            v["routes"],
            []
          ) :
          format("%s|%s|%s", v["name"], v["az_id"], y) if contains(coalesce(z["az_ids"], data.aws_availability_zones.region_azs.zone_ids), v["az_id"])
        ] if v["create"]
      ]
    ),
    flatten(
      [
        for k, v in
        flatten(
          [for x in local.subnets :
            values(x)
          ]
        ) :
        [
          for y, z in coalesce(
            v["routes"],
            []
          ) :
          {
            rt_name_tf_id     = format("%s-%s", v["name"], v["az_id"])
            route_tf_id       = format("%s|%s|%s", v["name"], v["az_id"], y)
            prefix_list_tf_id = format("%s|%s", v["name"], y)
            target            = z["target"]
          } if contains(coalesce(z["az_ids"], data.aws_availability_zones.region_azs.zone_ids), v["az_id"])
        ] if v["create"]
      ]
    )
  )


  route_table_id = aws_route_table.rt[each.value["rt_name_tf_id"]].id

  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_adhoc_route[each.value["prefix_list_tf_id"]].id


  #carrier_gateway_id        = startswith(each.value["target"], "") ? each.value["target"] : null
  #core_network_arn          = startswith(each.value["target"], "") ? each.value["target"] : null
  egress_only_gateway_id = startswith(each.value["target"], "eigw-") ? each.value["target"] : null
  #gateway_id                = startswith(each.value["target"], "") ? each.value["target"] : null
  nat_gateway_id = startswith(each.value["target"], "nat-") ? each.value["target"] : null
  #local_gateway_id          = startswith(each.value["target"], "") ? each.value["target"] : null
  network_interface_id      = startswith(each.value["target"], "eni-") ? each.value["target"] : null
  transit_gateway_id        = startswith(each.value["target"], "tgw-") ? each.value["target"] : null
  vpc_endpoint_id           = startswith(each.value["target"], "vpce-") ? each.value["target"] : null
  vpc_peering_connection_id = startswith(each.value["target"], "pcx-") ? each.value["target"] : null
}

###########################################################################################################################
###########################################################################################################################
###########################################################################################################################

resource "aws_network_acl" "nacl" {

  for_each = {
    for layer in var.vpc_config.subnet_layers : layer.name => layer
    if layer.create
  }

  vpc_id = try(
    aws_vpc.vpc["vpc"].id,
    var.vpc_config["vpc"]["vpc_id"]
  )

  egress {
    protocol   = -1
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    local.common_tags,
    tomap(
      {
        "Name"         = each.key
        "subnet_layer" = each.key
      }
    ),
    each.value["tags"]
  )

  lifecycle {
    ignore_changes = [egress, ingress]
  }
}

resource "aws_network_acl_rule" "default_ipv6_egress" {
  for_each = {
    for name, layer in zipmap(
      [for layer in var.vpc_config.subnet_layers : layer.name],
      var.vpc_config.subnet_layers
    ) : name => layer
    if layer.create && local.ipv6_enabled && layer.ipv6_enabled
  }

  network_acl_id  = aws_network_acl.nacl[each.key].id
  egress          = true
  protocol        = "-1"
  rule_action     = "allow"
  rule_number     = 201
  ipv6_cidr_block = "::/0"
}

resource "aws_network_acl_rule" "default_ipv6_ingress" {
  for_each = {
    for name, layer in zipmap(
      [for layer in var.vpc_config.subnet_layers : layer.name],
      var.vpc_config.subnet_layers
    ) : name => layer
    if layer.create && local.ipv6_enabled && layer.ipv6_enabled
  }

  network_acl_id  = aws_network_acl.nacl[each.key].id
  egress          = false
  protocol        = "-1"
  rule_action     = "allow"
  rule_number     = 201
  ipv6_cidr_block = "::/0"
}




resource "aws_network_acl_association" "nacl_association" {

  for_each = { for k, v in
    zipmap(
      flatten(
        [for x in local.subnets :
          keys(x)
        ]
      ),
      flatten(
        [for x in local.subnets :
          values(x)
        ]
      )
    ) :
    k => v if v["create"]
  }


  network_acl_id = each.value["network_acl_quarentine"] == true ? contains(coalesce(each.value["network_acl_quarentine_az_ids"], []), each.value["az_id"]) ? aws_default_network_acl.default_nacl_quarentine_subnets["vpc"].id : aws_network_acl.nacl[each.value["name"]].id : aws_network_acl.nacl[each.value["name"]].id

  subnet_id = aws_subnet.subnets[each.key].id
}

resource "aws_network_acl_rule" "nacl_rules" {

  for_each = zipmap(
    flatten(
      [
        for k, v in coalesce(var.vpc_config["subnet_layers"], []) :
        [
          for x, y in coalesce(v["network_acl_rules"], []) :
          format("%s-%s", v["name"], x) if v["create"]
        ]
      ]
    ),
    flatten(
      [
        for k, v in coalesce(var.vpc_config["subnet_layers"], []) :
        [
          for x, y in coalesce(v["network_acl_rules"], []) :
          merge({ "name" : v["name"] }, { "nacl_tf_id" : format("%s-%s", v["name"], x) }, y) if v["create"]
        ]
      ]
    )
  )

  network_acl_id = aws_network_acl.nacl[each.value["name"]].id
  rule_number    = each.value["rule_no"]
  egress         = each.value["egress"]
  protocol       = each.value["protocol"]
  rule_action    = each.value["action"]
  cidr_block     = each.value["cidr_block"]
  from_port      = each.value["from_port"]
  to_port        = each.value["to_port"]
  #icmp_code       = coalesce(each.value["icmp_code"], null)
  #icmp_type       = coalesce(each.value["icmp_type"], null)
  #ipv6_cidr_block = each.value["ipv6_cidr_block"] != null ? each.value["ipv6_cidr_block"] : null


  lifecycle {
    ignore_changes = [icmp_code, icmp_type, ipv6_cidr_block]
  }
}
