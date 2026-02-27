locals {

  #
  # List of subnets to be used to deploy NatGW
  #
  nat_instances_subnets = try(
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
            k => "natinstance_subnet" if(
              v["nat_instance_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_instance"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_instance_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_instance"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_instance"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_instance"]["az_widerange"]
      ),
      0
    ),
    null
  )

  #
  # List of subnets that should have route pointing the internet access throught Nat Instance
  #
  has_outbound_internet_access_via_natinstance = [for k, v in local.map_of_subnets :
    k if v["has_outbound_internet_access_via_natinstance"] == true
  ]

}



resource "aws_security_group" "natinstance_sg" {
  for_each = try(var.vpc_config["nat_instance"]["create"], false) == true ? { "sg_natinstance" : try(aws_vpc.vpc["vpc"], var.vpc_config["vpc"]) } : {}

  name        = each.key
  description = format("NatInstance SG - %s", each.value["id"])

  vpc_id = each.value["id"]

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    {
      "Name"                     = upper(format("NatInstance-%s", each.value["tags"]["stack"]))
      "opsteam:ParentObject"     = each.value["id"]
      "opsteam:ParentObjectArn"  = each.value["arn"]
      "opsteam:ParentObjectType" = "VPC"
    },
    local.common_tags
  )

}

#
# Deploy ENI for Nat Instances
#
resource "aws_network_interface" "natinstance_eni" {

  for_each = local.subnets != [] ? try(var.vpc_config["nat_instance"]["create"], false) == true ? toset(
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
            k => "natinstance_subnet" if(
              v["nat_instance_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_instance"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_instance_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_instance"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_instance"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_instance"]["az_widerange"]
      ),
      0
    )
  ) : toset([]) : toset([])

  subnet_id         = aws_subnet.subnets[each.key].id
  source_dest_check = false
  security_groups   = [aws_security_group.natinstance_sg["sg_natinstance"].id]
  tags = merge(
    tomap(
      {
        "Name" = format(
          "eip-eni-%s",
          each.key
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

#
# Deploy EIP allocation
#
resource "aws_eip" "natinstance_eip" {

  for_each = local.subnets != [] ? try(var.vpc_config["nat_instance"]["create"], false) == true ? toset(
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
            k => "natinstance_subnet" if(
              v["nat_instance_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_instance"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_instance_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_instance"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_instance"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_instance"]["az_widerange"]
      ),
      0
    )
  ) : toset([]) : toset([])

  vpc               = true
  network_interface = aws_network_interface.natinstance_eni[each.key].id
  tags = merge(
    tomap(
      {
        "Name" = upper(
          format(
            "eip-natinstance-%s",
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

#
# Deploy LaunchTemplate for Nat Instances
#
resource "aws_launch_template" "natinstance_lt" {

  for_each = local.subnets != [] ? try(var.vpc_config["nat_instance"]["create"], false) == true ? toset(
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
            k => "natinstance_subnet" if(
              v["nat_instance_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_instance"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_instance_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_instance"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_instance"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_instance"]["az_widerange"]
      ),
      0
    )
  ) : toset([]) : toset([])

  name_prefix   = format("lt-natinstance-%s", each.key)
  image_id      = var.vpc_config["nat_instance"]["ami_id"]
  instance_type = var.vpc_config["nat_instance"]["instance_type"]

  tags = local.common_tags

  network_interfaces {
    device_index         = 0
    network_interface_id = aws_network_interface.natinstance_eni[each.key].id
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

#
# Deploy ASG for each Nat Instances
#
resource "aws_autoscaling_group" "natinstance_asg" {
  for_each = local.subnets != [] ? try(var.vpc_config["nat_instance"]["create"], false) == true ? toset(
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
            k => "nat_instance" if(
              v["nat_instance_scope"] == "public"
              && contains(
                coalesce(
                  var.vpc_config["nat_instance"]["az_ids"],
                  data.aws_availability_zones.region_azs.zone_ids
                ),
                v["az_id"]
              )
              ) && (
              v["nat_instance_scope"] == "public"
              && contains(
                setsubtract(
                  coalesce(
                    var.vpc_config["nat_instance"]["az_ids"],
                    data.aws_availability_zones.region_azs.zone_ids
                  ),
                  coalesce(
                    var.vpc_config["nat_instance"]["exclude_az_ids"],
                    []
                  )
                ),
                v["az_id"]
              )
            )
          }
        ),
        var.vpc_config["nat_instance"]["az_widerange"]
      ),
      0
    )
  ) : toset([]) : toset([])

  name_prefix      = format("natinstance-%s", each.key)
  desired_capacity = 1
  max_size         = 1
  min_size         = 1
  availability_zones = toset(
    [
      element(
        data.aws_availability_zones.region_azs.names,
        index(
          data.aws_availability_zones.region_azs.zone_ids,
          local.map_of_subnets[each.key]["az_id"]
        )
      )
    ]
  )
  launch_template {
    id      = aws_launch_template.natinstance_lt[each.key].id
    version = aws_launch_template.natinstance_lt[each.key].latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_subnet.subnets
  ]
}

#
# Deploy Routes to Nat Instance
#
resource "aws_route" "r_natinstance" {
  for_each = local.subnets != [] ? var.vpc_config["nat_instance"]["create"] == true ? toset(local.has_outbound_internet_access_via_natinstance) : toset([]) : toset([])

  route_table_id             = aws_route_table.rt[each.key].id
  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_internet["vpc"].id
  #nat_gateway_id             = aws_nat_gateway.nat-gw[ element(local.nat_instances_subnets, index(local.has_outbound_internet_access_via_natinstance, each.key) ) ].id 
  network_interface_id = aws_network_interface.natinstance_eni[
    element(
      local.nat_instances_subnets,
      index(
        local.has_outbound_internet_access_via_natinstance,
        each.key
      )
    )
  ].id
}


# output "teste" {
#   value = local.nat_instances_subnets
# }
