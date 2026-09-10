locals {
  nat_gateway_candidate_subnets = {
    for key, subnet in local.map_of_subnets : key => subnet
    if subnet.create &&
    coalesce(subnet.nat_gw_scope, subnet.scope) == "public" &&
    contains(
      setsubtract(
        coalesce(var.vpc_config.nat_gateway.az_ids, data.aws_availability_zones.region_azs.zone_ids),
        coalesce(var.vpc_config.nat_gateway.exclude_az_ids, toset([]))
      ),
      subnet.az_id
    )
  }

  nat_gw_subnets = slice(
    sort(keys(local.nat_gateway_candidate_subnets)),
    0,
    min(var.vpc_config.nat_gateway.az_widerange, length(local.nat_gateway_candidate_subnets))
  )

  nat_gateway_route_subnets = {
    for key, subnet in local.map_of_subnets : key => subnet
    if subnet.create && subnet.has_outbound_internet_access_via_natgw
  }

  nat_gateway_subnet_by_az = {
    for subnet_key in coalesce(local.nat_gw_subnets, []) :
    local.map_of_subnets[subnet_key].az_id => subnet_key
  }

}

#
# Deploy EIP allocation
#
resource "aws_eip" "natgw_eip" {
  for_each = var.vpc_config.nat_gateway.create ? toset(local.nat_gw_subnets) : toset([])

  domain = "vpc"
  tags = merge(
    local.common_tags,
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
    )
  )

  depends_on = [
    aws_subnet.subnets
  ]

}

####
#### Deploy Nat GW
####
resource "aws_nat_gateway" "nat-gw" {
  for_each = var.vpc_config.nat_gateway.create ? toset(local.nat_gw_subnets) : toset([])

  allocation_id = aws_eip.natgw_eip[each.key].id
  subnet_id     = aws_subnet.subnets[each.key].id

  tags = merge(
    local.common_tags,
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
    )
  )

}

#
# Deploy Routes to Nat GW
#
resource "aws_route" "r_natgw" {
  for_each = var.vpc_config.nat_gateway.create ? local.nat_gateway_route_subnets : {}

  route_table_id             = aws_route_table.rt[each.key].id
  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_internet["vpc"].id
  nat_gateway_id = aws_nat_gateway.nat-gw[
    lookup(
      local.nat_gateway_subnet_by_az,
      local.map_of_subnets[each.key].az_id,
      element(local.nat_gw_subnets, 0)
    )
  ].id
}
