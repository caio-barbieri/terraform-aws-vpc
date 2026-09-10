#
# Deploy IGW 
#
resource "aws_internet_gateway" "igw" {
  for_each = alltrue([var.vpc_config["vpc"]["create"], var.vpc_config["igw"]["create"]]) ? tomap(
    {
      "vpc" = try(
        aws_vpc.vpc["vpc"],
        var.vpc_config["vpc"]
      )
    }
  ) : {}

  vpc_id = try(each.value["id"], each.value["vpc_id"])

  tags = merge(
    local.common_tags,
    tomap(
      {
        "Name" = upper(
          format(
            "igw-%s",
            try(
              each.value["tags"]["Name"],
              each.value["id"],
              each.value["vpc_id"]
            )
          )
        )
        "opsteam:ParentObject" = try(
          each.value["id"],
          each.value["vpc_id"]
        )
        "opsteam:ParentObjectArn" = try(
          each.value["arn"],
          null
        )
        "opsteam:ParentObjectType" = "VPC"
      }
    )
  )
}

#
# Deploy Route to IGW for public subnets using subnet layers
# 
resource "aws_route" "r_to_igw" {
  for_each = {
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
    k => "public_subnet" if v["create"] && v["scope"] == "public"
  }

  route_table_id             = aws_route_table.rt[each.key].id
  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_internet["vpc"].id
  gateway_id                 = local.internet_gateway_id

}



#########################################################################################################
#########################################################################################################
###
### Get the RouteTables to create route to IGW using filter.
###
##data "aws_route_tables" "rts_to_adhoc_igw" {
##
##  for_each = var.vpc_config["igw"]["route_tables_filter"] != null ? tomap({ "igw_rt_filter" = var.vpc_config["igw"]["route_tables_filter"] }) : {}
##  
##  vpc_id = try(
##    aws_vpc.vpc["vpc"].id,
##    var.vpc_config["vpc"]["vpc_id"]
##  )
##
##  filter {
##    name   = each.value["name"]
##    values = each.value["values"]
##  }
##}
##
###
### Deploy Route to IGW for public subnets using RouteTable filter input
### 
##resource "aws_route" "r_to_igw_from_rt_filter" {
##  for_each = var.vpc_config["igw"]["route_tables_filter"] != null ?zipmap(data.aws_route_tables.rts_to_adhoc_igw["igw_rt_filter"].ids, data.aws_route_tables.rts_to_adhoc_igw["igw_rt_filter"].ids) : {}
##
##  route_table_id         = each.value
##  destination_cidr_block = "0.0.0.0/0"
##  gateway_id             = aws_internet_gateway.igw["vpc"].id
##
##}
