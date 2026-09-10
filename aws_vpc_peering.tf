#
# Deploy Peering Requester
#
resource "aws_vpc_peering_connection" "peering_connection" {

  for_each = {
    for v in var.vpc_config["peering_connection"] :
    v["peer_vpc_id"] => v if v["peer_vpc_id"] != null
  }

  auto_accept = coalesce(
    each.value["peer_owner_id"],
    data.aws_caller_identity.session.account_id
  ) == data.aws_caller_identity.session.account_id ? each.value["auto_accept"] : false

  peer_owner_id = coalesce(
    each.value["peer_owner_id"],
    data.aws_caller_identity.session.account_id
  )

  peer_vpc_id = each.value["peer_vpc_id"]

  vpc_id = coalesce(
    each.value["vpc_id"],
    try(aws_vpc.vpc["vpc"].id, null),
    var.vpc_config.vpc.vpc_id
  )

  peer_region = each.value["peer_region"]

  accepter {
    allow_remote_vpc_dns_resolution = try(
      each.value["accepter"]["allow_remote_vpc_dns_resolution"],
      false
    )
  }

  requester {
    allow_remote_vpc_dns_resolution = try(
      each.value["requester"]["allow_remote_vpc_dns_resolution"],
      false
    )
  }

  tags = merge(
    local.common_tags,
    tomap(
      {
        "Name" = upper(
          format(
            "peer-connection-%s-to-%s",
            coalesce(each.value["vpc_id"], try(aws_vpc.vpc["vpc"].id, null), var.vpc_config.vpc.vpc_id),
            each.key
          )
        )
        "opsteam:ParentObject"     = coalesce(each.value["vpc_id"], try(aws_vpc.vpc["vpc"].id, null), var.vpc_config.vpc.vpc_id)
        "opsteam:ParentObjectArn"  = try(aws_vpc.vpc["vpc"].arn, null)
        "opsteam:ParentObjectType" = "VPC"
      }
    )
  )

  timeouts {
    create = "2m"
    update = "2m"
    delete = "2m"
  }

}


resource "aws_vpc_peering_connection_accepter" "peering_accept" {

  for_each = {
    for v in var.vpc_config["peering_connection"] :
    v["vpc_peering_connection_id"] => v if v["vpc_peering_connection_id"] != null
  }

  accepter {
    allow_remote_vpc_dns_resolution = try(
      each.value["accepter"]["allow_remote_vpc_dns_resolution"],
      false
    )
  }

  vpc_peering_connection_id = each.key
  auto_accept               = each.value["auto_accept"]
}

#
# Get the RouteTables to create route to Peering.
#
data "aws_route_tables" "rts_to_pwc" {

  for_each = {
    for v in var.vpc_config["peering_connection"] :
    coalesce(
      v["peer_vpc_id"],
      v["vpc_peering_connection_id"]
      ) => v if(
      length(compact([v["peer_vpc_id"], v["vpc_peering_connection_id"]])) > 0 &&
      v["route_table_ids"] == null &&
      !(var.vpc_config.vpc.create && v["vpc_id"] == null)
    )
  }

  vpc_id = coalesce(
    each.value["vpc_id"],
    try(aws_vpc.vpc["vpc"].id, null),
    var.vpc_config["vpc"]["vpc_id"]
  )

  filter {
    name   = each.value["route_tables_filter"]["name"]
    values = each.value["route_tables_filter"]["values"]
  }
}

locals {
  peering_connections = {
    for peering in var.vpc_config.peering_connection :
    coalesce(peering.peer_vpc_id, peering.vpc_peering_connection_id) => peering
  }

  peering_module_route_table_tags = {
    for key, subnet in local.map_of_subnets : key => merge(
      local.common_tags,
      subnet.tags,
      {
        Name         = key
        scope        = subnet.scope
        subnet_layer = subnet.name
      }
    ) if subnet.create
  }

  peering_route_entries = concat(
    flatten([
      for peering_key, peering in local.peering_connections : [
        for route_table_key, tags in local.peering_module_route_table_tags : {
          key            = "${peering_key}|module|${route_table_key}"
          peering_key    = peering_key
          route_table_id = aws_route_table.rt[route_table_key].id
          } if(
          var.vpc_config.vpc.create &&
          peering.vpc_id == null &&
          peering.route_table_ids == null &&
          contains(
            peering.route_tables_filter.values,
            lookup(tags, trimprefix(peering.route_tables_filter.name, "tag:"), "")
          )
        )
      ]
    ]),
    flatten([
      for peering_key, peering in local.peering_connections : [
        for route_table_id in coalesce(peering.route_table_ids, toset([])) : {
          key            = "${peering_key}|explicit|${route_table_id}"
          peering_key    = peering_key
          route_table_id = route_table_id
        }
      ]
    ]),
    flatten([
      for peering_key, peering in local.peering_connections : [
        for route_table_id in try(data.aws_route_tables.rts_to_pwc[peering_key].ids, toset([])) : {
          key            = "${peering_key}|filtered|${route_table_id}"
          peering_key    = peering_key
          route_table_id = route_table_id
        }
      ]
    ])
  )

  peering_routes = {
    for route in local.peering_route_entries : route.key => route
  }
}


#
# Deploy Managed Prefix List to handle the Peering routes
#
resource "aws_ec2_managed_prefix_list" "managed_prefixlist_peering_connection" {

  #  for_each = var.vpc_config["peering_connection"] != null ? { 
  #    for v in var.vpc_config["peering_connection"]:
  #      v["peer_vpc_id"] => v if v["peer_vpc_id"] != null
  #  } : {}

  for_each = {
    for v in var.vpc_config["peering_connection"] :
    coalesce(
      v["peer_vpc_id"],
      v["vpc_peering_connection_id"]
    ) => v if length(compact([v["peer_vpc_id"], v["vpc_peering_connection_id"]])) > 0
  }

  name           = upper(format("prefixlist-vpcpeer-%s", each.key))
  address_family = "IPv4"
  max_entries    = length(each.value["cidr_blocks"])


  dynamic "entry" {
    for_each = each.value["cidr_blocks"]

    content {
      cidr = entry.value
    }
  }


  tags = merge(
    local.common_tags,
    {
      "Name" = upper(format("prefixlist-internet-%s", each.key))
      "opsteam:ParentObject" = try(
        aws_vpc_peering_connection.peering_connection[each.key].id,
        each.key
      )
      "opsteam:ParentObjectType" = can(aws_vpc_peering_connection.peering_connection[each.key].id) ? "VPCPeeringConnection" : "VPCPeeringAccept"
    }
  )

}


resource "aws_route" "r_pwc" {
  for_each = local.peering_routes

  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_peering_connection[each.value.peering_key].id
  route_table_id             = each.value.route_table_id
  vpc_peering_connection_id = try(
    aws_vpc_peering_connection.peering_connection[each.value.peering_key].id,
    each.value.peering_key
  )

  depends_on = [
    data.aws_route_tables.rts_to_pwc,
    aws_vpc_peering_connection.peering_connection
  ]

}
