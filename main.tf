locals {
  common_tags = var.vpc_config.global.tags
  vpc_name = upper(coalesce(
    try(local.common_tags["name"], null),
    try(local.common_tags["stack"], null),
    try(local.common_tags["Name"], null),
    "vpc"
  ))
  vpc_name_slug = coalesce(
    trim(replace(lower(local.vpc_name), "/[^0-9a-z_-]/", "-"), "-"),
    "vpc"
  )
  default_dhcp_domain_name = data.aws_region.session.region == "us-east-1" ? "ec2.internal" : "${data.aws_region.session.region}.compute.internal"
  ipv6_enabled             = var.vpc_config.ipv6.enabled
  vpc_context = {
    id = try(
      aws_vpc.vpc["vpc"].id,
      data.aws_vpc.existing[0].id,
      var.vpc_config.vpc.vpc_id
    )
    cidr_block = try(
      aws_vpc.vpc["vpc"].cidr_block,
      data.aws_vpc.existing[0].cidr_block,
      var.vpc_config.vpc.cidr_block
    )
    arn = try(
      aws_vpc.vpc["vpc"].arn,
      data.aws_vpc.existing[0].arn,
      null
    )
  }
  internet_gateway_id = try(
    aws_internet_gateway.igw["vpc"].id,
    var.vpc_config.igw.internet_gateway_id
  )
  egress_only_internet_gateway_id = try(
    aws_egress_only_internet_gateway.ipv6["vpc"].id,
    var.vpc_config.ipv6.egress_only_internet_gateway_id
  )
  vpc_ipv6_cidr_block = try(
    coalesce(
      try(aws_vpc_ipv6_cidr_block_association.ipv6["vpc"].ipv6_cidr_block, null),
      var.vpc_config.ipv6.ipv6_cidr_block
    ),
    null
  )
}

data "aws_caller_identity" "session" {}

data "aws_region" "session" {}

data "aws_partition" "session" {}

data "aws_vpc" "existing" {
  count = !var.vpc_config.vpc.create && var.vpc_config.vpc.vpc_id != null ? 1 : 0
  id    = var.vpc_config.vpc.vpc_id
}
