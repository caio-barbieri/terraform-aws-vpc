output "vpc_ids" {
  description = "The IDs of the VPCs"
  value       = { for k, v in aws_vpc.vpc : k => try(v.id, null) }
}

output "vpc_id" {
  description = "The ID of the VPC created or managed by the module"
  value       = try(aws_vpc.vpc["vpc"].id, var.vpc_config.vpc.vpc_id)
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet layer and Availability Zone ID"
  value       = { for k, v in aws_subnet.subnets : k => v.id }
}

output "public_subnet_ids" {
  description = "IDs of subnets whose scope is public"
  value       = [for subnet in values(aws_subnet.subnets) : subnet.id if subnet.tags["scope"] == "public"]
}

output "private_subnet_ids" {
  description = "IDs of subnets whose scope is private"
  value       = [for subnet in values(aws_subnet.subnets) : subnet.id if subnet.tags["scope"] == "private"]
}

output "route_table_ids" {
  description = "Route table IDs keyed by subnet layer and Availability Zone ID"
  value       = { for k, v in aws_route_table.rt : k => v.id }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway created by or passed to the module"
  value       = local.internet_gateway_id
}

output "ipv6_cidr_block" {
  description = "IPv6 CIDR associated with the VPC"
  value       = local.vpc_ipv6_cidr_block
}

output "egress_only_internet_gateway_id" {
  description = "ID of the IPv6 egress-only Internet Gateway"
  value       = local.egress_only_internet_gateway_id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs keyed by public subnet"
  value       = { for k, v in aws_nat_gateway.nat-gw : k => v.id }
}

output "vpc_endpoint_ids" {
  description = "VPC endpoint IDs keyed by module endpoint key"
  value = merge(
    { for k, v in aws_vpc_endpoint.vpc_endpoint_gw : element(split("--", k), 1) => v.id },
    { for k, v in aws_vpc_endpoint.vpc_endpoint_interface : element(split("--", k), 1) => v.id }
  )
}

output "transit_gateway_ids" {
  description = "Transit Gateway IDs keyed by configured name"
  value = {
    for k, v in var.vpc_config.transit_gateway :
    k => try(aws_ec2_transit_gateway.transit_gateway[k].id, v.transit_gateway_id)
  }
}

output "transit_gateway_vpc_attachment_ids" {
  description = "Transit Gateway VPC attachment IDs keyed by Transit Gateway name"
  value       = { for key, attachment in aws_ec2_transit_gateway_vpc_attachment.vpc_attachment : key => attachment.id }
}

output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = try(aws_flow_log.vpc["vpc"].id, null)
}

output "vpc_flow_log_group_arn" {
  description = "CloudWatch Log Group ARN used by VPC Flow Logs"
  value       = local.flow_logs_to_cloudwatch ? local.flow_logs_log_group_arn : null
}

output "nat_instance_network_interface_ids" {
  description = "NAT Instance network interface IDs keyed by public subnet"
  value       = { for key, network_interface in aws_network_interface.natinstance_eni : key => network_interface.id }
}


output "sg_ids" {
  description = "Security Group IDs keyed by configured name"
  value       = { for k in aws_security_group.security_group : k.name => try(k.id, null) }
}


output "vpc_data" {
  value = { for k, v in aws_vpc.vpc : k => try(v, null) }
}

output "peering_connection_data" {
  value = { for k, v in aws_vpc_peering_connection.peering_connection : k => try(v, null) }
}
