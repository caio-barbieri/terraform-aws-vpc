variable "vpc_config" {
  description = "AWS VPC configurations"
  type = object(
    {
      dhcp_options = optional( # DHCP options set for the VPC
        object(
          {
            domain_name          = optional(string, "ec2.internal")             # Domain name for DHCP options set
            domain_name_servers  = optional(set(string), ["AmazonProvidedDNS"]) # DNS name servers for DHCP options set
            ntp_servers          = optional(set(string))                        # NTP servers for DHCP options set
            netbios_name_servers = optional(set(string))                        # NetBIOS name servers for DHCP options set
            netbios_node_type    = optional(string)                             # NetBIOS node type for DHCP options set
            tags                 = optional(map(string))                        # Tags for DHCP options set
          }
        ),
        {
          domain_name         = "ec2.internal"
          domain_name_servers = ["AmazonProvidedDNS"]
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
              )
            )
            tags = optional(map(string)) # Tags for the global VPC settings

          }
        )
      )
      igw = optional( # Internet Gateway settings for the VPC
        object(
          {
            create = optional(bool, true) # If 'true', will create a new Internet Gateway
            vpc_id = optional(string)     # The ID of an existing VPC to associate with the Internet Gateway
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
      nat_gateway = optional( # NAT Gateway configuration for the VPC
        object(
          {
            create         = optional(bool, false) # If 'true', will create a new NAT Gateway
            az_widerange   = optional(string, 2)   # The wider range of Availability Zones to use for the NAT Gateway
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
            ami_id               = optional(string)              #  ID of NatInstance Image imported by `import_natinstance_ami.sh` or console 
            create               = optional(bool, false)         # If 'true', will create a new NAT instance
            az_widerange         = optional(string, 2)           # The wider range of Availability Zones to use for the NAT instance
            az_ids               = optional(set(string))         # List of Availability Zone IDs to use for the NAT instance
            exclude_az_ids       = optional(set(string))         # List of Availability Zone IDs to exclude from use for the NAT instance
            instance_type        = optional(string, "t3.medium") # The instance type of the NAT instance
            key_name             = optional(string)              # SSH key pair name to associate with the NAT instance
            iam_instance_profile = optional(string)              # IAM instance profile name to attach to the NAT instance (e.g. for SSM access)
            instance_tags        = optional(map(string))         # Additional tags applied to the NAT instance itself
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
              route_tables_filter       = optional(any)         # Route table filter settings for the peering connection
              tags                      = optional(map(string)) # Tags for the VPC peering connection
              vpc_id                    = optional(string)      # The ID of the VPC initiating the peering connection
              vpc_peering_connection_id = optional(string)      # The ID of the VPC peering connection
            }
          )
        )
      )
      security_groups = optional( # Security group configuration for the VPC
        list(
          object(
            {
              description = optional(string) # Description of the security group
              egress = optional(             # Egress rule configuration for the security group
                list(
                  object(
                    {
                      description              = optional(string)      # Description of the egress rule
                      from_port                = optional(string)      # Starting port range for the egress rule
                      to_port                  = optional(string)      # Ending port range for the egress rule
                      protocol                 = optional(string)      # Protocol to use for the egress rule
                      cidr_blocks              = optional(set(string)) # List of CIDR blocks for the egress rule
                      ipv6_cidr_blocks         = optional(set(string)) # List of IPv6 CIDR blocks for the egress rule
                      prefix_list_ids          = optional(set(string)) # List of prefix list IDs for the egress rule
                      source_security_group_id = optional(string)      # Security group id to allow access to/from, depending on the type. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or self.
                      self                     = optional(string)      #   Whether the security group itself will be added as a source to this ingress rule. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or source_security_group_id.

                    }
                  )
                )
              )
              ingress = optional( # Ingress rule configuration for the security group
                list(
                  object(
                    {
                      description              = optional(string)      # Description of the ingress rule
                      from_port                = optional(string)      # Starting port range for the ingress rule
                      to_port                  = optional(string)      # Ending port range for the ingress rule
                      protocol                 = optional(string)      # Protocol to use for the ingress rule
                      cidr_blocks              = optional(set(string)) # List of CIDR blocks for the ingress rule
                      ipv6_cidr_blocks         = optional(set(string)) # List of IPv6 CIDR blocks for the ingress rule
                      prefix_list_ids          = optional(set(string)) # List of prefix list IDs for the ingress rule
                      source_security_group_id = optional(string)      # Security group id to allow access to/from, depending on the type. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or self.
                      self                     = optional(string)      #   Whether the security group itself will be added as a source to this ingress rule. Cannot be specified with cidr_blocks, ipv6_cidr_blocks, or source_security_group_id.
                    }
                  )
                )
              )
              name_prefix            = optional(string)      # Prefix for the security group name
              name                   = optional(string)      # Name of the security group
              revoke_rules_on_delete = optional(string)      # If 'true', will revoke all rules when the security group is deleted.  This is normally not needed, however certain AWS services such as Elastic Map Reduce may automatically add required rules to security groups used with the service, and those rules may contain a cyclic dependency that prevent the security groups from being destroyed without removing the dependency first. Default false.
              vpc_id                 = optional(string)      # The ID of the VPC for the security group
              tags                   = optional(map(string)) # Tags for the security group
            }
          )
        )
      )
      subnet_layers = optional( # Subnet layers configuration for the VPC
        list(
          object(
            {
              az_widerange                                 = optional(string, 3)    # The wider range of Availability Zones to use for the subnet
              az_ids                                       = optional(set(string))  # List of Availability Zone IDs to use for the subnet
              cidr_block                                   = optional(list(string)) # CIDR block for the subnet
              create                                       = optional(bool, true)   # If 'true', will create a new subnet
              enable_resource_name_dns_a_record_on_launch  = optional(bool, false)  # If 'true', will enable DNS A record on launch
              has_outbound_internet_access_via_natgw       = optional(bool, false)  # If 'true', will have outbound internet access via NAT Gateway
              has_outbound_internet_access_via_natinstance = optional(bool, false)  # If 'true', will have outbound internet access via NAT instance
              map_public_ip_on_launch                      = optional(bool, false)  # If 'true', will map public IP on launch
              name                                         = optional(string)       # Name of the subnet
              nat_gw_scope                                 = optional(string)       # Scope of the NAT Gateway
              nat_instance_scope                           = optional(string)       # Scope of the NAT instance
              netprefix                                    = optional(string)       # Prefix for the network
              netlength                                    = optional(string, 0)    # Length of the network
              netnum                                       = optional(string, 0)    # Number of the network
              network_acl_quarentine                       = optional(bool, false)  # If 'true', will block access in network ACLs, but keeps services running. Ou seja, bloqueia acesso nas NACLs, mas deixa os servicos ligados
              network_acl_quarentine_az_ids                = optional(set(string))  # List of Availability Zone IDs for the network ACL quarantine
              network_acl_rules = optional(                                         # Network ACL rules configuration
                list(
                  object(
                    {
                      action          = optional(string)      # Action for the ACL rule
                      egress          = optional(bool, false) # If 'true', is an egress rule
                      cidr_block      = optional(string)      # CIDR block for the ACL rule
                      from_port       = optional(string)      # Starting port range for the ACL rule
                      icmp_code       = optional(string)      # ICMP code for the ACL rule
                      icmp_type       = optional(string)      # ICMP type for the ACL rule
                      ipv6_cidr_block = optional(string)      # IPv6 CIDR block for the ACL rule
                      protocol        = optional(string)      # Protocol for the ACL rule
                      rule_no         = optional(string)      # Rule number
                      to_port         = optional(string)      # Ending port range for the ACL rule
                    }
                  )
                )
              )
              private_dns_hostname_type_on_launch = optional(string) # Type of private DNS hostname on launch
              routes = optional(                                     # Route configuration for the subnet
                list(
                  object(
                    {
                      az_ids                 = optional(set(string))  # List of Availability Zone IDs for the route
                      destination_cidr_block = optional(list(string)) # Destination CIDR block for the route
                      target                 = optional(string)       # Target for the route
                    }
                  )
                )
              )
              scope  = optional(string, "private") # Scope of the subnet ('private' by default)
              vpc_id = optional(string)            # VPC ID for the subnet
              tags   = optional(map(string))       # Tags for the subnet
            }
          )
        )
      )
      transit_gateway = optional( # Security group configuration for the VPC
        map(
          object(
            {
              amazon_side_asn                 = optional(string)      # Private Autonomous System Number (ASN) for the Amazon side of a BGP session. The range is 64512 to 65534 for 16-bit ASNs and 4200000000 to 4294967294 for 32-bit ASNs. Default value: 64512.            
              auto_accept_shared_attachments  = optional(string)      #  Whether resource attachment requests are automatically accepted. Valid values: disable, enable. Default value: disable.
              create                          = optional(bool, true)  # If 'true', will create a new transitgateway  (if 'false', the transit_gateway_id will be used to locate an existing transit gateway ). Ou seja, se false, não vai criar transit gateway, e será trabalhado com o transit_gateway_id (item abixo) que indica qual é o transit_gateway que está sendo trabalhado.
              default_route_table_association = optional(string)      # Whether resource attachments are automatically associated with the default association route table. Valid values: disable, enable. Default value: enable.
              default_route_table_propagation = optional(string)      #  Whether resource attachments automatically propagate routes to the default propagation route table. Valid values: disable, enable. Default value: enable.
              description                     = optional(string)      # Description of the EC2 Transit Gateway.
              dns_support                     = optional(string)      # Whether DNS support is enabled. Valid values: disable, enable. Default value: enable.
              multicast_support               = optional(string)      # Whether Multicast support is enabled. Required to use ec2_transit_gateway_multicast_domain. Valid values: disable, enable. Default value: disable.
              tags                            = optional(map(string)) # Key-value tags for the EC2 Transit Gateway. If configured with a provider default_tags configuration block present, tags with matching keys will overwrite those defined at the provider-level.
              transit_gateway_id              = optional(string)      # transit gateway ID (used if 'create' is 'false')
              transit_gateway_cidr_blocks     = optional(set(string)) # One or more IPv4 or IPv6 CIDR blocks for the transit gateway. Must be a size /24 CIDR block or larger for IPv4, or a size /64 CIDR block or larger for IPv6.
              vpc_attachment_filter = optional(                       # Filter to select which VPC will be attached to the given transit gateway
                object(
                  {
                    name   = optional(string)      # Name of the tags to be check for filter
                    values = optional(set(string)) # Values of the tags to be check for filter
                  }
                )
              )
              vpn_ecmp_support = optional(string) # Whether VPN Equal Cost Multipath Protocol support is enabled. Valid values: disable, enable. Default value: enable.

            }
          )
        )
      )
      vpc = optional( # VPC configuration
        object(
          {
            create = optional(bool, true) # If 'true', will create a new VPC (if 'false', the vpc_id will be used to locate an existing VPC). Ou seja, se false, não vai criar uma VPC, e será trabalhado com o vpc_id (item abixo) que indica qual é a VPC que está sendp trabalhada.

            cidr_block                           = optional(string)            # CIDR block for the VPC
            enable_dns_hostnames                 = optional(bool, true)        # If 'true', will enable DNS hostnames for the VPC
            enable_dns_support                   = optional(bool, true)        # If 'true', will enable DNS support for the VPC
            enable_network_address_usage_metrics = optional(bool, false)       # If 'true', will enable network address usage metrics for the VPC
            instance_tenancy                     = optional(string, "default") # Instance tenancy for the VPC ('default' by default)
            ipv4_ipam_pool_id                    = optional(string)            # IPv4 IPAM pool ID for the VPC
            ipv4_netmask_length                  = optional(string, 20)        # IPv4 netmask length for the VPC
            tags                                 = optional(map(string))       # Tags for the VPC
            vpc_id                               = optional(string)            # VPC ID (used if 'create' is 'false')
          }
        )
      )
      vpc_endpoints = optional( # VPC endpoint configuration
        map(
          object(
            {
              az_ids                               = optional(set(string))   # List of Availability Zone IDs for the endpoint
              exclude_az_ids                       = optional(set(string))   # List of Availability Zone IDs to exclude from the endpoint
              service_type                         = optional(string)        # Service type for the endpoint
              auto_accept                          = optional(bool, false)   # If 'true', will auto accept the endpoint
              policy                               = optional(string)        # Policy for the endpoint
              private_dns_enabled                  = optional(string, true)  # If 'true', will enable private DNS for the endpoint
              endpoint_service_private_dns_enabled = optional(string, false) # If 'true', will enable private DNS for the endpoint service
              dns_options = optional(                                        # DNS options for the endpoint
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
                    name   = optional(string)      # Name of the route table filter
                    values = optional(set(string)) # Values for the route table filter
                  }
                )
              )
              listener_ports = optional( # Listener ports for the endpoint
                object(
                  {
                    from_port       = optional(string)      # Starting port for the listener
                    to_port         = optional(string)      # Ending port for the listener
                    protocol        = optional(string)      # Protocol for the listener
                    security_groups = optional(set(string)) # Security groups for the listener
                  }
                ),
                {
                  from_port = "443"
                  to_port   = "443"
                  protocol  = "tcp"
                }
              )
              subnet_filter = optional( # Subnet filter for the endpoint
                object(
                  {
                    name   = optional(string)      # Name of the subnet filter
                    values = optional(set(string)) # Values for the subnet filter
                  }
                ),
                {
                  name   = "tag:subnet_layer",
                  values = ["awssvc"]
                }
              )
              tags = optional(map(string))
            }
          )
        )
      )
    }
  )
}
