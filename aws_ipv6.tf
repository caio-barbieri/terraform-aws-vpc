resource "aws_vpc_ipv6_cidr_block_association" "ipv6" {
  for_each = local.ipv6_enabled && var.vpc_config.vpc.create ? { "vpc" = var.vpc_config.ipv6 } : {}

  vpc_id = aws_vpc.vpc["vpc"].id

  assign_generated_ipv6_cidr_block = each.value.assign_generated_ipv6_cidr_block ? true : null
  ipv6_cidr_block                  = each.value.assign_generated_ipv6_cidr_block ? null : each.value.ipv6_cidr_block
  ipv6_ipam_pool_id                = each.value.assign_generated_ipv6_cidr_block ? null : each.value.ipv6_ipam_pool_id
  ipv6_netmask_length              = each.value.assign_generated_ipv6_cidr_block ? null : each.value.ipv6_netmask_length
  ipv6_pool                        = each.value.assign_generated_ipv6_cidr_block ? null : each.value.ipv6_pool
}

resource "aws_egress_only_internet_gateway" "ipv6" {
  for_each = local.ipv6_enabled && var.vpc_config.ipv6.create_egress_only_internet_gateway && anytrue([
    for layer in var.vpc_config.subnet_layers : layer.create && layer.ipv6_enabled && layer.scope != "public"
  ]) ? { "vpc" = local.vpc_context.id } : {}

  vpc_id = each.value

  tags = merge(
    local.common_tags,
    {
      Name = "EIGW-${local.vpc_name}"
    }
  )
}

resource "aws_route" "ipv6_public" {
  for_each = {
    for key, subnet in local.map_of_subnets : key => subnet
    if subnet.create && local.ipv6_enabled && subnet.ipv6_enabled && subnet.scope == "public"
  }

  route_table_id              = aws_route_table.rt[each.key].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = local.internet_gateway_id
}

resource "aws_route" "ipv6_private" {
  for_each = {
    for key, subnet in local.map_of_subnets : key => subnet
    if subnet.create && local.ipv6_enabled && subnet.ipv6_enabled && subnet.scope != "public"
  }

  route_table_id              = aws_route_table.rt[each.key].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = local.egress_only_internet_gateway_id
}
