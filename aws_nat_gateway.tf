locals {

  #
  # List of subnets to be used to deploy NatGW
  #
  nat_gw_subnets = try(
    element(
      chunklist(
        keys(
          { for k, v in zipmap(
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
            k => "natgw_subnet" if(
              v["nat_gw_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_gateway"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_gw_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_gateway"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_gateway"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_gateway"]["az_widerange"]
      ),
      0
    ),
    null
  )

  #
  # List of subnets that should have route pointing the internet access throught Nat GW
  #
  has_outbound_internet_access_via_natgw = [for k, v in local.map_of_subnets :
    k if v["has_outbound_internet_access_via_natgw"] == true
  ]

}

#
# Deploy EIP allocation
#
resource "aws_eip" "natgw_eip" {

  for_each = local.subnets != [] ? try(var.vpc_config["nat_gateway"]["create"], false) == true ? toset(
    element(
      chunklist(
        keys(
          { for k, v in zipmap(
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
            k => "natgw_subnet" if(
              v["nat_gw_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_gateway"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_gw_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_gateway"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_gateway"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_gateway"]["az_widerange"]
      ),
      0
    )
  ) : toset([]) : toset([])

  vpc = true
  tags = merge(
    tomap(
      {
        "Name" = upper(
          format(
            "eip-natgw-%s",
            each.key
          )
        )
        "opsteam:ParentObject"     = aws_subnet.subnets[each.key].id
        "opsteam:ParentObjectArn"  = aws_subnet.subnets[each.key].arn
        "opsteam:ParentObjectType" = "Subnet"
      }
    ),
    local.common_tags
  )

  depends_on = [
    aws_subnet.subnets
  ]

}

####
#### Deploy Nat GW
####
resource "aws_nat_gateway" "nat-gw" {

  for_each = local.subnets != [] ? var.vpc_config["nat_gateway"]["create"] == true ? toset(
    element(
      chunklist(
        keys(
          { for k, v in zipmap(
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
            k => "natgw_subnet" if(
              v["nat_gw_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_gateway"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_gw_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_gateway"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_gateway"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_gateway"]["az_widerange"]
      ),
      0
    )
  ) : toset([]) : toset([])

  allocation_id = aws_eip.natgw_eip[each.key].id
  subnet_id     = aws_subnet.subnets[each.key].id

  tags = merge(
    tomap(
      {
        "Name" = upper(
          format(
            "eip-natgw-%s",
            each.key
          )
        )
        "opsteam:ParentObject"     = aws_subnet.subnets[each.key].id
        "opsteam:ParentObjectArn"  = aws_subnet.subnets[each.key].arn
        "opsteam:ParentObjectType" = "Subnet"
      }
    ),
    local.common_tags
  )

}

#
# Deploy Routes to Nat GW
#
resource "aws_route" "r_natgw" {
  for_each = local.subnets != [] ? var.vpc_config["nat_gateway"]["create"] == true ? toset(local.has_outbound_internet_access_via_natgw) : toset([]) : toset([])

  route_table_id             = aws_route_table.rt[each.key].id
  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_internet["vpc"].id
  nat_gateway_id             = aws_nat_gateway.nat-gw[element(local.nat_gw_subnets, index(local.has_outbound_internet_access_via_natgw, each.key))].id
}
