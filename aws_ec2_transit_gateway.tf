#
# Create transit gateway for the current VPC
#
resource "aws_ec2_transit_gateway" "transit_gateway" {
  for_each = { for k, v in var.vpc_config.transit_gateway : k => v if v.create }

  amazon_side_asn                 = try(each.value.amazon_side_asn, null)
  auto_accept_shared_attachments  = try(each.value.auto_accept_shared_attachments, "disable")
  default_route_table_association = try(each.value.default_route_table_association, "enable")
  default_route_table_propagation = try(each.value.default_route_table_propagation, "enable")
  description                     = each.value.description
  dns_support                     = try(each.value.dns_support, "enable")
  multicast_support               = try(each.value.multicast_support, "disable")
  vpn_ecmp_support                = try(each.value.vpn_ecmp_support, "enable")
  transit_gateway_cidr_blocks     = try(each.value.transit_gateway_cidr_blocks, null)
  tags = merge(
    local.common_tags,
    each.value.tags,
    tomap(
      {
        "Name" = upper(each.key)
      }
    )
  )
}

locals {
  transit_gateway_attachments = {
    for name, config in var.vpc_config.transit_gateway : name => config
    if config.vpc_attachment.create
  }

  transit_gateway_routes = {
    for item in flatten([
      for transit_gateway_name, transit_gateway in var.vpc_config.transit_gateway : [
        for route_name, route in transit_gateway.transit_gateway_routes : {
          key                  = "${transit_gateway_name}--${route_name}"
          transit_gateway_name = transit_gateway_name
          transit_gateway      = transit_gateway
          route                = route
        }
      ]
    ]) : item.key => item
  }

  transit_gateway_vpc_routes = {
    for item in flatten([
      for transit_gateway_name, transit_gateway in var.vpc_config.transit_gateway : [
        for route_name, route in transit_gateway.vpc_routes : [
          for route_table_key in coalesce(
            route.route_table_ids,
            toset([
              for key, subnet in local.map_of_subnets : key
              if subnet.create && contains(route.subnet_layer_names, subnet.name)
            ])
            ) : {
            key                  = "${transit_gateway_name}--${route_name}--${route_table_key}"
            transit_gateway_name = transit_gateway_name
            transit_gateway      = transit_gateway
            route                = route
            route_table_key      = route_table_key
          }
        ]
      ]
    ]) : item.key => item
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
  for_each = local.transit_gateway_attachments

  transit_gateway_id = try(
    aws_ec2_transit_gateway.transit_gateway[each.key].id,
    each.value.transit_gateway_id
  )
  vpc_id = local.vpc_context.id
  subnet_ids = coalesce(
    each.value.vpc_attachment.subnet_ids,
    toset([
      for subnet in values(aws_subnet.subnets) : subnet.id
      if contains(each.value.vpc_attachment.subnet_layer_names, subnet.tags["subnet_layer"])
    ])
  )

  appliance_mode_support                          = each.value.vpc_attachment.appliance_mode_support
  dns_support                                     = each.value.vpc_attachment.dns_support
  ipv6_support                                    = each.value.vpc_attachment.ipv6_support
  security_group_referencing_support              = each.value.vpc_attachment.security_group_referencing_support
  transit_gateway_default_route_table_association = each.value.vpc_attachment.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = each.value.vpc_attachment.transit_gateway_default_route_table_propagation

  tags = merge(
    local.common_tags,
    each.value.vpc_attachment.tags,
    {
      Name = upper("${each.key}-${local.vpc_name}")
    }
  )
}

resource "aws_ec2_transit_gateway_route" "route" {
  for_each = local.transit_gateway_routes

  destination_cidr_block = each.value.route.destination_cidr_block
  blackhole              = each.value.route.blackhole
  transit_gateway_attachment_id = each.value.route.blackhole ? null : aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[
    each.value.transit_gateway_name
  ].id
  transit_gateway_route_table_id = coalesce(
    each.value.route.transit_gateway_route_table_id,
    try(
      aws_ec2_transit_gateway.transit_gateway[each.value.transit_gateway_name].association_default_route_table_id,
      null
    )
  )
}

resource "aws_route" "transit_gateway" {
  for_each = local.transit_gateway_vpc_routes

  route_table_id = startswith(each.value.route_table_key, "rtb-") ? each.value.route_table_key : aws_route_table.rt[
    each.value.route_table_key
  ].id
  destination_cidr_block = each.value.route.destination_cidr_block
  transit_gateway_id = try(
    aws_ec2_transit_gateway.transit_gateway[each.value.transit_gateway_name].id,
    each.value.transit_gateway.transit_gateway_id
  )

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.vpc_attachment]
}
