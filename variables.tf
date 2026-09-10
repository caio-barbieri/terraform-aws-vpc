variable "vpc_config" {
  description = "AWS VPC configurations"
  type = object(
    {
      dhcp_options = optional( # DHCP options set for the VPC
        object(
          {
            domain_name          = optional(string)                             # Domain name for DHCP options set
            domain_name_servers  = optional(set(string), ["AmazonProvidedDNS"]) # DNS name servers for DHCP options set
            ntp_servers          = optional(set(string))                        # NTP servers for DHCP options set
            netbios_name_servers = optional(set(string))                        # NetBIOS name servers for DHCP options set
            netbios_node_type    = optional(string)                             # NetBIOS node type for DHCP options set
            tags                 = optional(map(string), {})                    # Tags for DHCP options set
          }
        ),
        {
          domain_name_servers = ["AmazonProvidedDNS"]
        }
      )
      flow_logs = optional(
        object(
          {
            create                       = optional(bool, false)
            cloudwatch_kms_key_id        = optional(string)
            cloudwatch_log_group_name    = optional(string)
            cloudwatch_retention_in_days = optional(number, 90)
            destination_options = optional(
              object(
                {
                  file_format                = optional(string, "plain-text")
                  hive_compatible_partitions = optional(bool, false)
                  per_hour_partition         = optional(bool, false)
                }
              )
            )
            iam_role_arn             = optional(string)
            log_destination_arn      = optional(string)
            log_destination_type     = optional(string, "cloud-watch-logs")
            log_format               = optional(string)
            max_aggregation_interval = optional(number, 60)
            tags                     = optional(map(string), {})
            traffic_type             = optional(string, "ALL")
          }
        ),
        {
          create = false
        }
      )
      global = optional( # Global VPC settings
        object(
          {
            az = optional( # Availability Zone settings
              object(
                {
                  exclude_zone_ids = optional(set(string)) # List of excluded Zone IDs
                  state            = optional(string)      # The state of the Availability Zone
                }
              ),
              {}
            )
            tags = optional(map(string), {}) # Tags for the global VPC settings

          }
        ),
        {}
      )
      igw = optional( # Internet Gateway settings for the VPC
        object(
          {
            create              = optional(bool, true) # If 'true', will create a new Internet Gateway
            internet_gateway_id = optional(string)     # Existing Internet Gateway ID used when create is false
            vpc_id              = optional(string)     # The ID of an existing VPC to associate with the Internet Gateway
          }
        ),
        {
          create = true
        }
      )
      ipam = optional( # IPAM pool settings for the VPC
        object(
          {
            ipam_pool_id = optional(string) # The ID of the IPAM pool
          }
        )
      )
      ipv6 = optional(
        object(
          {
            assign_generated_ipv6_cidr_block    = optional(bool, true)
            create_egress_only_internet_gateway = optional(bool, true)
            egress_only_internet_gateway_id     = optional(string)
            enabled                             = optional(bool, false)
            ipv6_cidr_block                     = optional(string)
            ipv6_ipam_pool_id                   = optional(string)
            ipv6_netmask_length                 = optional(number)
            ipv6_pool                           = optional(string)
          }
        ),
        {
          enabled = false
        }
      )
      nat_gateway = optional( # NAT Gateway configuration for the VPC
        object(
          {
            create         = optional(bool, false) # If 'true', will create a new NAT Gateway
            az_widerange   = optional(number, 2)   # The wider range of Availability Zones to use for the NAT Gateway
            az_ids         = optional(set(string)) # List of Availability Zone IDs to use for the NAT Gateway
            exclude_az_ids = optional(set(string)) # List of Availability Zone IDs to exclude from use for the NAT Gateway
          }
        ),
        {
          create = false # NAT instance configuration for the VPC
        }
      )
      nat_instance = optional(
        object(
          {
            ami_id                    = optional(string)              # ID of a consumer-managed NAT AMI
            create                    = optional(bool, false)         # If 'true', will create a new NAT instance
            az_widerange              = optional(number, 2)           # The wider range of Availability Zones to use for the NAT instance
            az_ids                    = optional(set(string))         # List of Availability Zone IDs to use for the NAT instance
            exclude_az_ids            = optional(set(string))         # List of Availability Zone IDs to exclude from use for the NAT instance
            health_check_grace_period = optional(number, 300)         # Seconds before EC2 health checks can replace the NAT instance
            iam_instance_profile      = optional(string)              # Compatibility alias for iam_instance_profile_name
            iam_instance_profile_name = optional(string)              # IAM instance profile name for the NAT instance
            instance_tags             = optional(map(string), {})     # Additional tags for NAT EC2 instances
            instance_type             = optional(string, "t3.medium") # The instance type of the NAT instance
            key_name                  = optional(string)              # SSH key pair name to associate with the NAT instance
          }
        ),
        {
          create = false
        }
      )
      peering_connection = optional( # VPC peering connection configuration
        list(
          object(
            {
              accepter = optional( # Accepter VPC peering settings
                object(
                  {
                    allow_remote_vpc_dns_resolution = optional(bool, false) # If 'true', will allow the accepter VPC to resolve DNS from the peered VPC
                  }
                )
              )
              auto_accept   = optional(bool, true)  # If 'true', will automatically accept the peering connection
              cidr_blocks   = optional(set(string)) # List of CIDR blocks for the peering connection
              peer_owner_id = optional(string)      # The AWS account ID of the owner of the peered VPC
              peer_region   = optional(string)      # The region in which the peered VPC is located
              peer_vpc_id   = optional(string)      # The ID of the peered VPC
              requester = optional(                 # Requester VPC peering settings
                object(
                  {
                    allow_remote_vpc_dns_resolution = optional(bool, false) # If 'true', will allow the requester VPC to resolve DNS from the peered VPC
                  }
                )
              )
              route_tables_filter = optional( # Route table filter settings for the peering connection
                object(
                  {
                    name   = string
                    values = set(string)
                  }
                )
              )
              route_table_ids           = optional(set(string))     # Explicit route table IDs; alternative to route_tables_filter
              tags                      = optional(map(string), {}) # Tags for the VPC peering connection
              vpc_id                    = optional(string)          # The ID of the VPC initiating the peering connection
              vpc_peering_connection_id = optional(string)          # The ID of the VPC peering connection
            }
          )
        ),
        []
      )
      security_groups = optional( # Security group configuration for the VPC
        list(
          object(
            {
              description = optional(string, "Managed by Terraform") # Description of the security group
              egress = optional(                                     # Egress rule configuration for the security group
                list(
                  object(
                    {
                      description              = optional(string)      # Description of the egress rule
                      from_port                = number                # Starting port range for the egress rule
                      to_port                  = number                # Ending port range for the egress rule
                      protocol                 = string                # Protocol to use for the egress rule
                      cidr_blocks              = optional(set(string)) # List of CIDR blocks for the egress rule
                      ipv6_cidr_blocks         = optional(set(string)) # List of IPv6 CIDR blocks for the egress rule
                      prefix_list_ids          = optional(set(string)) # List of prefix list IDs for the egress rule
                      source_security_group_id = optional(string)      # Security group id to allow access to/from, depending on the type. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or self.
                      self                     = optional(bool)        # Whether the security group itself will be added as a source to this egress rule.

                    }
                  )
                ),
                []
              )
              ingress = optional( # Ingress rule configuration for the security group
                list(
                  object(
                    {
                      description              = optional(string)      # Description of the ingress rule
                      from_port                = number                # Starting port range for the ingress rule
                      to_port                  = number                # Ending port range for the ingress rule
                      protocol                 = string                # Protocol to use for the ingress rule
                      cidr_blocks              = optional(set(string)) # List of CIDR blocks for the ingress rule
                      ipv6_cidr_blocks         = optional(set(string)) # List of IPv6 CIDR blocks for the ingress rule
                      prefix_list_ids          = optional(set(string)) # List of prefix list IDs for the ingress rule
                      source_security_group_id = optional(string)      # Security group id to allow access to/from, depending on the type. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or self.
                      self                     = optional(bool)        # Whether the security group itself will be added as a source to this ingress rule.
                    }
                  )
                ),
                []
              )
              name_prefix            = optional(string)          # Prefix for the security group name
              name                   = string                    # Name of the security group
              revoke_rules_on_delete = optional(bool, false)     # If 'true', will revoke all rules when the security group is deleted.
              vpc_id                 = optional(string)          # The ID of the VPC for the security group
              tags                   = optional(map(string), {}) # Tags for the security group
            }
          )
        ),
        []
      )
      subnet_layers = optional( # Subnet layers configuration for the VPC
        list(
          object(
            {
              az_widerange                                   = optional(number, 3)    # The wider range of Availability Zones to use for the subnet
              az_ids                                         = optional(set(string))  # List of Availability Zone IDs to use for the subnet
              assign_ipv6_address_on_creation                = optional(bool, true)   # Assign IPv6 addresses to new network interfaces when IPv6 is enabled
              cidr_block                                     = optional(list(string)) # CIDR block for the subnet
              create                                         = optional(bool, true)   # If 'true', will create a new subnet
              enable_dns64                                   = optional(bool, false)  # Synthesize AAAA records for IPv4-only destinations
              enable_resource_name_dns_a_record_on_launch    = optional(bool, false)  # If 'true', will enable DNS A record on launch
              enable_resource_name_dns_aaaa_record_on_launch = optional(bool, true)   # Enable DNS AAAA records when IPv6 is enabled
              has_outbound_internet_access_via_natgw         = optional(bool, false)  # If 'true', will have outbound internet access via NAT Gateway
              has_outbound_internet_access_via_natinstance   = optional(bool, false)  # If 'true', will have outbound internet access via NAT instance
              map_public_ip_on_launch                        = optional(bool, false)  # If 'true', will map public IP on launch
              name                                           = string                 # Name of the subnet
              nat_gw_scope                                   = optional(string)       # Scope of the NAT Gateway
              nat_instance_scope                             = optional(string)       # Scope of the NAT instance
              netprefix                                      = optional(string)       # Prefix for the network
              netlength                                      = optional(number, 8)    # Additional IPv4 prefix bits used when CIDRs are derived
              netnum                                         = optional(number)       # Optional first derived subnet number; otherwise allocated by layer order
              network_acl_quarentine                         = optional(bool, false)  # If 'true', will block access in network ACLs, but keeps services running. Ou seja, bloqueia acesso nas NACLs, mas deixa os servicos ligados
              network_acl_quarentine_az_ids                  = optional(set(string))  # List of Availability Zone IDs for the network ACL quarantine
              network_acl_rules = optional(                                           # Network ACL rules configuration
                list(
                  object(
                    {
                      action          = optional(string)      # Action for the ACL rule
                      egress          = optional(bool, false) # If 'true', is an egress rule
                      cidr_block      = optional(string)      # CIDR block for the ACL rule
                      from_port       = optional(number)      # Starting port range for the ACL rule
                      icmp_code       = optional(number)      # ICMP code for the ACL rule
                      icmp_type       = optional(number)      # ICMP type for the ACL rule
                      ipv6_cidr_block = optional(string)      # IPv6 CIDR block for the ACL rule
                      protocol        = optional(string)      # Protocol for the ACL rule
                      rule_no         = optional(number)      # Rule number
                      to_port         = optional(number)      # Ending port range for the ACL rule
                    }
                  )
                ),
                []
              )
              private_dns_hostname_type_on_launch = optional(string)       # Type of private DNS hostname on launch
              ipv6_cidr_block                     = optional(list(string)) # Explicit /64 CIDRs; derived automatically when omitted
              ipv6_enabled                        = optional(bool, true)   # Enable dual-stack addressing for this layer
              routes = optional(                                           # Route configuration for the subnet
                list(
                  object(
                    {
                      az_ids                 = optional(set(string))  # List of Availability Zone IDs for the route
                      destination_cidr_block = optional(list(string)) # Destination CIDR block for the route
                      target                 = optional(string)       # Target for the route
                    }
                  )
                ),
                []
              )
              scope  = optional(string, "private") # Scope of the subnet ('private' by default)
              vpc_id = optional(string)            # VPC ID for the subnet
              tags   = optional(map(string), {})   # Tags for the subnet
            }
          )
        ),
        []
      )
      transit_gateway = optional( # Security group configuration for the VPC
        map(
          object(
            {
              amazon_side_asn                 = optional(number)          # Private Autonomous System Number (ASN) for the Amazon side of a BGP session. The range is 64512 to 65534 for 16-bit ASNs and 4200000000 to 4294967294 for 32-bit ASNs. Default value: 64512.
              auto_accept_shared_attachments  = optional(string)          #  Whether resource attachment requests are automatically accepted. Valid values: disable, enable. Default value: disable.
              create                          = optional(bool, true)      # If 'true', will create a new transitgateway  (if 'false', the transit_gateway_id will be used to locate an existing transit gateway ). Ou seja, se false, não vai criar transit gateway, e será trabalhado com o transit_gateway_id (item abixo) que indica qual é o transit_gateway que está sendo trabalhado.
              default_route_table_association = optional(string)          # Whether resource attachments are automatically associated with the default association route table. Valid values: disable, enable. Default value: enable.
              default_route_table_propagation = optional(string)          #  Whether resource attachments automatically propagate routes to the default propagation route table. Valid values: disable, enable. Default value: enable.
              description                     = optional(string)          # Description of the EC2 Transit Gateway.
              dns_support                     = optional(string)          # Whether DNS support is enabled. Valid values: disable, enable. Default value: enable.
              multicast_support               = optional(string)          # Whether Multicast support is enabled. Required to use ec2_transit_gateway_multicast_domain. Valid values: disable, enable. Default value: disable.
              tags                            = optional(map(string), {}) # Key-value tags for the EC2 Transit Gateway. If configured with a provider default_tags configuration block present, tags with matching keys will overwrite those defined at the provider-level.
              transit_gateway_id              = optional(string)          # transit gateway ID (used if 'create' is 'false')
              transit_gateway_cidr_blocks     = optional(set(string))     # One or more IPv4 or IPv6 CIDR blocks for the transit gateway. Must be a size /24 CIDR block or larger for IPv4, or a size /64 CIDR block or larger for IPv6.
              vpc_attachment = optional(
                object(
                  {
                    appliance_mode_support                          = optional(string, "disable")
                    create                                          = optional(bool, false)
                    dns_support                                     = optional(string, "enable")
                    ipv6_support                                    = optional(string, "disable")
                    security_group_referencing_support              = optional(string)
                    subnet_ids                                      = optional(set(string))
                    subnet_layer_names                              = optional(set(string), ["private"])
                    tags                                            = optional(map(string), {})
                    transit_gateway_default_route_table_association = optional(bool, true)
                    transit_gateway_default_route_table_propagation = optional(bool, true)
                  }
                ),
                {
                  create = false
                }
              )
              transit_gateway_routes = optional(
                map(
                  object(
                    {
                      blackhole                      = optional(bool, false)
                      destination_cidr_block         = string
                      transit_gateway_route_table_id = optional(string)
                    }
                  )
                ),
                {}
              )
              vpc_routes = optional(
                map(
                  object(
                    {
                      destination_cidr_block = string
                      route_table_ids        = optional(set(string))
                      subnet_layer_names     = optional(set(string), ["private"])
                    }
                  )
                ),
                {}
              )
              vpn_ecmp_support = optional(string) # Whether VPN Equal Cost Multipath Protocol support is enabled. Valid values: disable, enable. Default value: enable.

            }
          )
        ),
        {}
      )
      vpc = object( # VPC configuration
        {
          create = optional(bool, true) # If 'true', will create a new VPC (if 'false', the vpc_id will be used to locate an existing VPC). Ou seja, se false, não vai criar uma VPC, e será trabalhado com o vpc_id (item abixo) que indica qual é a VPC que está sendp trabalhada.

          cidr_block                           = optional(string)            # CIDR block for the VPC
          enable_dns_hostnames                 = optional(bool, true)        # If 'true', will enable DNS hostnames for the VPC
          enable_dns_support                   = optional(bool, true)        # If 'true', will enable DNS support for the VPC
          enable_network_address_usage_metrics = optional(bool, false)       # If 'true', will enable network address usage metrics for the VPC
          instance_tenancy                     = optional(string, "default") # Instance tenancy for the VPC ('default' by default)
          ipv4_ipam_pool_id                    = optional(string)            # IPv4 IPAM pool ID for the VPC
          ipv4_netmask_length                  = optional(number, 20)        # IPv4 netmask length for the VPC
          tags                                 = optional(map(string), {})   # Tags for the VPC
          vpc_id                               = optional(string)            # VPC ID (used if 'create' is 'false')
        }
      )
      vpc_endpoints = optional( # VPC endpoint configuration
        map(
          object(
            {
              az_ids                               = optional(set(string)) # List of Availability Zone IDs for the endpoint
              exclude_az_ids                       = optional(set(string)) # List of Availability Zone IDs to exclude from the endpoint
              service_type                         = string                # Service type for the endpoint
              auto_accept                          = optional(bool, false) # If 'true', will auto accept the endpoint
              policy                               = optional(string)      # Policy for the endpoint
              private_dns_enabled                  = optional(bool, true)  # If 'true', will enable private DNS for the endpoint
              endpoint_service_private_dns_enabled = optional(bool, false) # If 'true', will enable private DNS for the endpoint service
              dns_options = optional(                                      # DNS options for the endpoint
                object(
                  {
                    dns_record_ip_type = optional(string) # DNS record IP type for the endpoint
                  }
                ),
                {
                  dns_record_ip_type = "ipv4"
                }
              )
              ip_address_type = optional(string, "ipv4") # IP address type for the endpoint
              route_tables_filter = optional(            # Route table filter for the endpoint
                object(
                  {
                    name   = string      # Name of the route table filter
                    values = set(string) # Values for the route table filter
                  }
                )
              )
              route_table_ids = optional(set(string)) # Explicit route table IDs for Gateway endpoints
              listener_ports = optional(              # Listener ports for the endpoint
                object(
                  {
                    from_port       = optional(number)      # Starting port for the listener
                    to_port         = optional(number)      # Ending port for the listener
                    protocol        = optional(string)      # Protocol for the listener
                    security_groups = optional(set(string)) # Security groups for the listener
                  }
                ),
                {
                  from_port = 443
                  to_port   = 443
                  protocol  = "tcp"
                }
              )
              subnet_filter = optional( # Subnet filter for the endpoint
                object(
                  {
                    name   = string      # Name of the subnet filter
                    values = set(string) # Values for the subnet filter
                  }
                ),
                {
                  name   = "tag:subnet_layer",
                  values = ["awssvc"]
                }
              )
              subnet_ids = optional(set(string)) # Explicit subnet IDs for Interface endpoints
              tags       = optional(map(string), {})
            }
          )
        ),
        {}
      )
    }
  )

  validation {
    condition = var.vpc_config.vpc.create ? (
      length(compact([
        var.vpc_config.vpc.cidr_block,
        var.vpc_config.vpc.ipv4_ipam_pool_id,
        try(var.vpc_config.ipam.ipam_pool_id, null)
      ])) == 1
      ) : (
      var.vpc_config.vpc.vpc_id != null
    )
    error_message = "When vpc.create is true, configure exactly one IPv4 source: vpc.cidr_block, vpc.ipv4_ipam_pool_id, or the legacy ipam.ipam_pool_id alias. When false, configure vpc_id."
  }

  validation {
    condition     = length(distinct([for layer in var.vpc_config.subnet_layers : layer.name])) == length(var.vpc_config.subnet_layers)
    error_message = "Each subnet layer must have a unique name."
  }

  validation {
    condition = !var.vpc_config.nat_instance.create || (
      var.vpc_config.nat_instance.ami_id != null &&
      can(regex("^ami-[0-9a-f]+$", var.vpc_config.nat_instance.ami_id))
    )
    error_message = "nat_instance.ami_id must be a valid AMI ID when nat_instance.create is true."
  }

  validation {
    condition = (
      var.vpc_config.nat_instance.iam_instance_profile == null ||
      var.vpc_config.nat_instance.iam_instance_profile_name == null ||
      var.vpc_config.nat_instance.iam_instance_profile == var.vpc_config.nat_instance.iam_instance_profile_name
    )
    error_message = "nat_instance.iam_instance_profile and nat_instance.iam_instance_profile_name must match when both are set."
  }

  validation {
    condition = alltrue([
      for endpoint in values(var.vpc_config.vpc_endpoints) :
      contains(["gateway", "interface", "endpointservice"], lower(endpoint.service_type))
    ])
    error_message = "vpc_endpoints[*].service_type must be Gateway, Interface, or endpointservice."
  }

  validation {
    condition = alltrue([
      for peering in var.vpc_config.peering_connection :
      ((peering.peer_vpc_id != null) != (peering.vpc_peering_connection_id != null)) &&
      ((peering.route_tables_filter != null) != (peering.route_table_ids != null)) &&
      (peering.route_table_ids == null || length(peering.route_table_ids) > 0) &&
      length(coalesce(peering.cidr_blocks, [])) > 0
    ])
    error_message = "Each peering connection must set exactly one connection ID, exactly one of route_tables_filter or non-empty route_table_ids, and at least one cidr_blocks entry."
  }

  validation {
    condition = alltrue([
      for peering in var.vpc_config.peering_connection :
      !var.vpc_config.vpc.create || peering.vpc_id != null || peering.route_table_ids != null || startswith(peering.route_tables_filter.name, "tag:")
    ])
    error_message = "Peering routes for a VPC created by this module require route_table_ids or a tag-based route_tables_filter."
  }

  validation {
    condition = alltrue([
      for transit_gateway in values(var.vpc_config.transit_gateway) :
      transit_gateway.create || transit_gateway.transit_gateway_id != null
    ])
    error_message = "transit_gateway_id is required when transit_gateway.create is false."
  }

  validation {
    condition = (
      !var.vpc_config.flow_logs.create ||
      contains(["cloud-watch-logs", "s3", "kinesis-data-firehose"], var.vpc_config.flow_logs.log_destination_type)
      ) && (
      !var.vpc_config.flow_logs.create ||
      contains(["ACCEPT", "REJECT", "ALL"], upper(var.vpc_config.flow_logs.traffic_type))
      ) && (
      !var.vpc_config.flow_logs.create ||
      contains([60, 600], var.vpc_config.flow_logs.max_aggregation_interval)
      ) && (
      !var.vpc_config.flow_logs.create ||
      var.vpc_config.flow_logs.log_destination_type == "cloud-watch-logs" ||
      var.vpc_config.flow_logs.log_destination_arn != null
    )
    error_message = "flow_logs must use a supported destination/traffic type and aggregation interval; S3 and Firehose require log_destination_arn."
  }

  validation {
    condition = !var.vpc_config.ipv6.enabled || (
      var.vpc_config.vpc.create ? (
        var.vpc_config.ipv6.assign_generated_ipv6_cidr_block ||
        var.vpc_config.ipv6.ipv6_cidr_block != null ||
        var.vpc_config.ipv6.ipv6_ipam_pool_id != null ||
        var.vpc_config.ipv6.ipv6_pool != null
        ) : (
        var.vpc_config.ipv6.ipv6_cidr_block != null
      )
    )
    error_message = "IPv6 requires an allocation source for a new VPC, or ipv6.ipv6_cidr_block for an existing VPC."
  }

  validation {
    condition = !var.vpc_config.ipv6.enabled || !var.vpc_config.ipv6.assign_generated_ipv6_cidr_block || (
      var.vpc_config.ipv6.ipv6_cidr_block == null &&
      var.vpc_config.ipv6.ipv6_ipam_pool_id == null &&
      var.vpc_config.ipv6.ipv6_pool == null
    )
    error_message = "assign_generated_ipv6_cidr_block conflicts with explicit IPv6 CIDR, IPAM pool, and IPv6 pool inputs."
  }

  validation {
    condition = !var.vpc_config.ipv6.enabled || !anytrue([
      for layer in var.vpc_config.subnet_layers : layer.create && layer.ipv6_enabled && layer.scope != "public"
      ]) || (
      var.vpc_config.ipv6.create_egress_only_internet_gateway != (var.vpc_config.ipv6.egress_only_internet_gateway_id != null)
    )
    error_message = "Private IPv6 subnets require exactly one of create_egress_only_internet_gateway or egress_only_internet_gateway_id."
  }

  validation {
    condition = !anytrue([
      for layer in var.vpc_config.subnet_layers : layer.create && layer.scope == "public"
      ]) || (
      (var.vpc_config.vpc.create && var.vpc_config.igw.create) ||
      var.vpc_config.igw.internet_gateway_id != null
    )
    error_message = "Public subnet layers require a module-created Internet Gateway or igw.internet_gateway_id."
  }

  validation {
    condition = alltrue([
      var.vpc_config.nat_gateway.az_widerange > 0,
      var.vpc_config.nat_instance.az_widerange > 0,
      alltrue([for layer in var.vpc_config.subnet_layers : layer.az_widerange > 0])
    ])
    error_message = "All az_widerange values must be greater than zero."
  }

  validation {
    condition = alltrue([
      for layer in var.vpc_config.subnet_layers :
      !layer.create || layer.cidr_block == null || length(layer.cidr_block) >= (
        layer.az_ids != null ? length(layer.az_ids) : layer.az_widerange
      )
    ])
    error_message = "Each explicit subnet_layers[*].cidr_block list must contain one CIDR per selected Availability Zone."
  }

  validation {
    condition = alltrue([
      for layer in var.vpc_config.subnet_layers :
      !layer.create || !var.vpc_config.ipv6.enabled || !layer.ipv6_enabled || layer.ipv6_cidr_block == null || length(layer.ipv6_cidr_block) >= (
        layer.az_ids != null ? length(layer.az_ids) : layer.az_widerange
      )
    ])
    error_message = "Each explicit subnet_layers[*].ipv6_cidr_block list must contain one CIDR per selected Availability Zone."
  }

  validation {
    condition = !var.vpc_config.nat_gateway.create || anytrue([
      for layer in var.vpc_config.subnet_layers :
      layer.create && coalesce(layer.nat_gw_scope, layer.scope) == "public"
    ])
    error_message = "nat_gateway.create requires at least one created public subnet layer."
  }

  validation {
    condition = !var.vpc_config.nat_instance.create || anytrue([
      for layer in var.vpc_config.subnet_layers :
      layer.create && coalesce(layer.nat_instance_scope, layer.scope) == "public"
    ])
    error_message = "nat_instance.create requires at least one created public subnet layer."
  }

  validation {
    condition = alltrue([
      for layer in var.vpc_config.subnet_layers :
      !layer.has_outbound_internet_access_via_natgw || var.vpc_config.nat_gateway.create
    ])
    error_message = "A subnet layer with NAT Gateway egress requires nat_gateway.create to be true."
  }

  validation {
    condition = alltrue([
      for layer in var.vpc_config.subnet_layers :
      !layer.has_outbound_internet_access_via_natinstance || var.vpc_config.nat_instance.create
    ])
    error_message = "A subnet layer with NAT Instance egress requires nat_instance.create to be true."
  }

  validation {
    condition = alltrue(flatten([
      for transit_gateway in values(var.vpc_config.transit_gateway) : [
        for route in values(transit_gateway.transit_gateway_routes) :
        transit_gateway.create || route.transit_gateway_route_table_id != null
      ]
    ]))
    error_message = "Transit Gateway routes for an existing gateway require transit_gateway_route_table_id."
  }

  validation {
    condition = alltrue([
      for transit_gateway in values(var.vpc_config.transit_gateway) :
      (length(transit_gateway.vpc_routes) == 0 && alltrue([
        for route in values(transit_gateway.transit_gateway_routes) : route.blackhole
      ])) ||
      transit_gateway.vpc_attachment.create
    ])
    error_message = "Transit Gateway and VPC routes managed by this module require vpc_attachment.create to be true."
  }

  validation {
    condition = alltrue([
      for transit_gateway in values(var.vpc_config.transit_gateway) :
      !transit_gateway.vpc_attachment.create || (
        transit_gateway.vpc_attachment.subnet_ids != null ?
        length(transit_gateway.vpc_attachment.subnet_ids) > 0 :
        length(setintersection(
          transit_gateway.vpc_attachment.subnet_layer_names,
          toset([for layer in var.vpc_config.subnet_layers : layer.name if layer.create])
        )) > 0
      )
    ])
    error_message = "A Transit Gateway VPC attachment requires explicit subnet_ids or at least one configured subnet_layer_name."
  }

  validation {
    condition = alltrue(flatten([
      for transit_gateway in values(var.vpc_config.transit_gateway) : [
        for route in values(transit_gateway.vpc_routes) :
        route.route_table_ids != null ? length(route.route_table_ids) > 0 : length(setintersection(
          route.subnet_layer_names,
          toset([for layer in var.vpc_config.subnet_layers : layer.name if layer.create])
        )) > 0
      ]
    ]))
    error_message = "Each Transit Gateway VPC route requires explicit route_table_ids or at least one configured subnet_layer_name."
  }
}
