locals {
  nat_instance_candidate_subnets = {
    for key, subnet in local.map_of_subnets : key => subnet
    if subnet.create &&
    coalesce(subnet.nat_instance_scope, subnet.scope) == "public" &&
    contains(
      setsubtract(
        coalesce(var.vpc_config.nat_instance.az_ids, data.aws_availability_zones.region_azs.zone_ids),
        coalesce(var.vpc_config.nat_instance.exclude_az_ids, toset([]))
      ),
      subnet.az_id
    )
  }

  nat_instances_subnets = slice(
    sort(keys(local.nat_instance_candidate_subnets)),
    0,
    min(var.vpc_config.nat_instance.az_widerange, length(local.nat_instance_candidate_subnets))
  )

  nat_instance_route_subnets = {
    for key, subnet in local.map_of_subnets : key => subnet
    if subnet.create && subnet.has_outbound_internet_access_via_natinstance
  }

  nat_instance_subnet_by_az = {
    for subnet_key in coalesce(local.nat_instances_subnets, []) :
    local.map_of_subnets[subnet_key].az_id => subnet_key
  }

}



resource "aws_security_group" "natinstance_sg" {
  for_each = var.vpc_config.nat_instance.create ? { "sg_natinstance" = local.vpc_context } : {}

  name        = each.key
  description = format("NatInstance SG - %s", each.value.id)

  vpc_id = each.value.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [each.value.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = local.ipv6_enabled ? ["::/0"] : []
  }

  tags = merge(
    local.common_tags,
    {
      "Name"                     = format("NATINSTANCE-%s", local.vpc_name)
      "opsteam:ParentObject"     = each.value.id
      "opsteam:ParentObjectArn"  = each.value.arn
      "opsteam:ParentObjectType" = "VPC"
    }
  )

}

#
# Deploy ENI for Nat Instances
#
resource "aws_network_interface" "natinstance_eni" {
  for_each = var.vpc_config.nat_instance.create ? toset(local.nat_instances_subnets) : toset([])

  subnet_id         = aws_subnet.subnets[each.key].id
  source_dest_check = false
  security_groups   = [aws_security_group.natinstance_sg["sg_natinstance"].id]
  tags = merge(
    local.common_tags,
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
    )
  )

  depends_on = [
    aws_subnet.subnets
  ]
}

#
# Deploy EIP allocation
#
resource "aws_eip" "natinstance_eip" {
  for_each = var.vpc_config.nat_instance.create ? toset(local.nat_instances_subnets) : toset([])

  domain            = "vpc"
  network_interface = aws_network_interface.natinstance_eni[each.key].id
  tags = merge(
    local.common_tags,
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
    )
  )

  depends_on = [
    aws_subnet.subnets
  ]

}

#
# Deploy LaunchTemplate for Nat Instances
#
resource "aws_launch_template" "natinstance_lt" {
  for_each = var.vpc_config.nat_instance.create ? toset(local.nat_instances_subnets) : toset([])

  name_prefix   = format("lt-natinstance-%s", each.key)
  image_id      = var.vpc_config["nat_instance"]["ami_id"]
  instance_type = var.vpc_config["nat_instance"]["instance_type"]

  tags = local.common_tags

  dynamic "iam_instance_profile" {
    for_each = var.vpc_config.nat_instance.iam_instance_profile_name != null ? [var.vpc_config.nat_instance.iam_instance_profile_name] : []
    content {
      name = iam_instance_profile.value
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interfaces {
    device_index         = 0
    network_interface_id = aws_network_interface.natinstance_eni[each.key].id
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      var.vpc_config.nat_instance.instance_tags,
      {
        Name = upper(format("natinstance-%s", each.key))
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

#
# Deploy ASG for each Nat Instances
#
resource "aws_autoscaling_group" "natinstance_asg" {
  for_each = var.vpc_config.nat_instance.create ? toset(local.nat_instances_subnets) : toset([])

  name_prefix               = format("natinstance-%s", each.key)
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  health_check_type         = "EC2"
  health_check_grace_period = var.vpc_config.nat_instance.health_check_grace_period
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
  for_each = var.vpc_config.nat_instance.create ? local.nat_instance_route_subnets : {}

  route_table_id             = aws_route_table.rt[each.key].id
  destination_prefix_list_id = aws_ec2_managed_prefix_list.managed_prefixlist_internet["vpc"].id
  network_interface_id = aws_network_interface.natinstance_eni[
    lookup(
      local.nat_instance_subnet_by_az,
      local.map_of_subnets[each.key].az_id,
      element(local.nat_instances_subnets, 0)
    )
  ].id
}
