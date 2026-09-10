# VPC Endpoint Gateway

#data "aws_vpc_endpoint_service" "dsfds" {
#  service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-02bb719817b4acce2"
#  #service_type = "Gateway"
#}

#
# Get data about VPC Endpoints to discover the service name endpoint.
#
data "aws_vpc_endpoint_service" "endpoint" {
  for_each = zipmap(
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        format("%s--%s--%s", try(
          local.common_tags["name"],
          local.common_tags["stack"],
          "null"
          ),
          x,
          y["service_type"]
        ) if contains(toset(["Gateway", "Interface"]), title(y["service_type"]))
      ]
    ),
    flatten(
      [
        for y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        y if contains(toset(["Gateway", "Interface"]), title(y["service_type"]))
      ]
    )
  )

  service      = element(split("--", each.key), 1)
  service_type = title(each.value["service_type"])
}

#
# Get the RouteTables to Gateway Endpoints.
#
data "aws_route_tables" "rts_to_gw-endpoints" {

  for_each = zipmap(
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        format("%s--%s--%s", try(
          local.common_tags["name"],
          local.common_tags["stack"],
          "null"
          ),
          x,
          y["service_type"]
        ) if try(y["route_tables_filter"], null) != null && try(y["route_table_ids"], null) == null
      ]
    ),
    flatten(
      [
        for y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        y if try(y["route_tables_filter"], null) != null && try(y["route_table_ids"], null) == null
      ]
    )
  )

  vpc_id = try(
    aws_vpc.vpc["vpc"].id,
    var.vpc_config["vpc"]["vpc_id"]
  )

  filter {
    name   = each.value["route_tables_filter"]["name"]
    values = each.value["route_tables_filter"]["values"]
  }

}


#
# Deploy VPC Endpoint type Gateway
#
resource "aws_vpc_endpoint" "vpc_endpoint_gw" {

  for_each = zipmap(
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        format("%s--%s--%s", try(
          local.common_tags["name"],
          local.common_tags["stack"],
          "null"
          ),
          x,
          y["service_type"]
        ) if title(y["service_type"]) == "Gateway"
      ]
    ),
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        y if title(y["service_type"]) == "Gateway"
      ]
    )
  )

  vpc_id = try(
    aws_vpc.vpc["vpc"].id,
    var.vpc_config["vpc"]["vpc_id"]
  )

  service_name = data.aws_vpc_endpoint_service.endpoint[each.key].service_name
  auto_accept  = each.value["auto_accept"]
  policy       = each.value["policy"]
  route_table_ids = coalesce(
    each.value["route_table_ids"],
    try(data.aws_route_tables.rts_to_gw-endpoints[each.key].ids, null),
    toset(values(aws_route_table.rt)[*].id)
  )
  vpc_endpoint_type = title(each.value["service_type"])
  tags = merge(
    local.common_tags,
    each.value["tags"],
    {
      "Name" = format("vpce|%s", each.key)
    }
  )

  depends_on = [
    aws_route_table.rt
  ]
}


############################################################################################################################
############################################################################################################################
############################################################################################################################

# VPC Endpoint Interface


#
# VPC Endpoint SecurityGroup
#
resource "aws_security_group" "sg-vpce-interface" {
  for_each = zipmap(
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        format("%s--%s--%s", try(
          local.common_tags["name"],
          local.common_tags["stack"],
          "null"
          ),
          x,
          y["service_type"]
        ) if title(y["service_type"]) == "Interface" || lower(y["service_type"]) == "endpointservice"
      ]
    ),
    flatten(
      [
        for y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        y if title(y["service_type"]) == "Interface" || lower(y["service_type"]) == "endpointservice"
      ]
    )
  )

  name        = format("vpce-sg-%s", each.key)
  description = format("VPC Endpoint SG %s", each.key)

  vpc_id = try(
    aws_vpc.vpc["vpc"].id,
    var.vpc_config["vpc"]["vpc_id"]
  )

  dynamic "ingress" {
    for_each = [each.value["listener_ports"]]
    content {
      from_port = ingress.value["from_port"]
      to_port   = ingress.value["to_port"]
      protocol  = ingress.value["protocol"]
      cidr_blocks = length(coalesce(ingress.value["security_groups"], toset([]))) == 0 ? toset(
        [
          local.vpc_context.cidr_block
        ]
      ) : null
      ipv6_cidr_blocks = length(coalesce(ingress.value["security_groups"], toset([]))) == 0 && local.ipv6_enabled ? toset([
        local.vpc_ipv6_cidr_block
      ]) : null

      security_groups = length(coalesce(ingress.value["security_groups"], toset([]))) > 0 ? ingress.value["security_groups"] : null

    }
  }

  tags = merge(
    local.common_tags,
    {
      "Name" = format("vpce-sg--%s", each.key)
    }
  )

}

#
# Retrieve Subnet IDs to deploy Endpoint Interfaces
#
data "aws_subnets" "subnets-vpce-interface" {
  for_each = zipmap(
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        format("%s--%s--%s", try(
          local.common_tags["name"],
          local.common_tags["stack"],
          "null"
          ),
          x,
          y["service_type"]
        ) if(title(y["service_type"]) == "Interface" || lower(y["service_type"]) == "endpointservice") && try(y["subnet_ids"], null) == null
      ]
    ),
    flatten(
      [
        for y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        y if(title(y["service_type"]) == "Interface" || lower(y["service_type"]) == "endpointservice") && try(y["subnet_ids"], null) == null
      ]
    )
  )

  filter {
    name = "vpc-id"
    values = [
      try(
        aws_vpc.vpc["vpc"].id,
        var.vpc_config["vpc"]["vpc_id"]
      )
    ]
  }

  filter {
    name   = each.value["subnet_filter"]["name"]
    values = each.value["subnet_filter"]["values"]
  }

  dynamic "filter" {
    for_each = each.value["az_ids"] != null ? [each.value["az_ids"]] : []
    content {
      name   = "availabilityZoneId"
      values = filter.value
    }
  }

  dynamic "filter" {
    for_each = each.value["exclude_az_ids"] != null ? [each.value["exclude_az_ids"]] : []
    content {
      name = "availabilityZoneId"
      values = setsubtract(
        data.aws_availability_zones.region_azs.zone_ids,
        filter.value
      )
    }
  }

}


#
# Deploy VPC Endpoint type Interface
#
resource "aws_vpc_endpoint" "vpc_endpoint_interface" {

  for_each = zipmap(
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        format("%s--%s--%s", try(
          local.common_tags["name"],
          local.common_tags["stack"],
          "null"
          ),
          x,
          y["service_type"]
        ) if title(y["service_type"]) == "Interface" || lower(y["service_type"]) == "endpointservice"
      ]
    ),
    flatten(
      [
        for x, y in coalesce(var.vpc_config["vpc_endpoints"], {}) :
        merge(y, { "service_type" : "Interface", "service_name" : x }) if title(y["service_type"]) == "Interface" || lower(y["service_type"]) == "endpointservice"
      ]
    )
  )

  vpc_id = try(
    aws_vpc.vpc["vpc"].id,
    var.vpc_config["vpc"]["vpc_id"]
  )

  service_name = try(
    data.aws_vpc_endpoint_service.endpoint[each.key].service_name,
    element(split("--", each.key), 1)
  )


  dynamic "dns_options" {
    for_each = [each.value["dns_options"]]
    content {
      dns_record_ip_type = dns_options.value["dns_record_ip_type"]
    }
  }

  auto_accept         = each.value["auto_accept"]
  policy              = each.value["policy"]
  private_dns_enabled = startswith(each.value["service_name"], "com.amazonaws.vpce") ? each.value["endpoint_service_private_dns_enabled"] : each.value["private_dns_enabled"]
  ip_address_type     = each.value["ip_address_type"]

  security_group_ids = toset([aws_security_group.sg-vpce-interface[each.key].id])
  subnet_ids = coalesce(
    each.value["subnet_ids"],
    try(data.aws_subnets.subnets-vpce-interface[each.key].ids, null)
  )
  vpc_endpoint_type = title(each.value["service_type"])

  tags = merge(
    local.common_tags,
    each.value["tags"],
    {
      "Name" = format("vpce-sg--%s", each.key)
    }
  )

  depends_on = [
    aws_subnet.subnets
  ]

}
