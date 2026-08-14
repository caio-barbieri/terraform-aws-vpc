#
# Add inbound rules on Security Group
#
resource "aws_security_group_rule" "ingress_rules" {
  for_each = { for item in flatten(
    [
      for sg in coalesce(var.vpc_config["security_groups"], []) :
      [
        for rule in coalesce(sg["ingress"], []) :
        merge(
          rule,
          tomap(
            {
              "sg_name" = sg["name"]
            }
          )
        )
      ]
    ]
    ) :

    #
    # Joining all itens from the object and converting to string
    # to generate hash to be used as key of this resource.
    #
    format(
      "%s",
      md5(
        format(
          "%s%s%s%s%s%s%s%s%s",
          item["from_port"],
          item["to_port"],
          item["protocol"],
          join("|", coalesce(item["cidr_blocks"], [])),
          coalesce(item["description"], " "),
          join("|", tolist(coalesce(item["ipv6_cidr_blocks"], []))),
          join("|", tolist(coalesce(item["prefix_list_ids"], []))),
          coalesce(item["source_security_group_id"], " "),
          item["self"] == null ? " " : tostring(item["self"]),
        )
      )
    ) => item
  }

  type                     = "ingress"
  from_port                = each.value["from_port"]
  to_port                  = each.value["to_port"]
  protocol                 = each.value["protocol"]
  cidr_blocks              = each.value["cidr_blocks"]
  description              = each.value["description"]
  ipv6_cidr_blocks         = each.value["ipv6_cidr_blocks"]
  prefix_list_ids          = each.value["prefix_list_ids"]
  source_security_group_id = each.value["source_security_group_id"]
  self                     = each.value["self"]
  security_group_id        = aws_security_group.security_group[each.value.sg_name].id
}

#
# Add outbound rules on Security Group
#
resource "aws_security_group_rule" "egress_rules" {
  for_each = { for item in flatten(
    [
      for sg in coalesce(var.vpc_config["security_groups"], []) :
      [
        for rule in coalesce(sg["egress"], []) :
        merge(
          rule,
          tomap(
            {
              "sg_name" = sg["name"]
            }
          )
        )
      ]
    ]
    ) :

    #
    # Joining all itens from the object and converting to string
    # to generate hash to be used as key of this resource.
    #
    format(
      "%s",
      md5(
        format(
          "%s%s%s%s%s%s%s%s%s",
          item["from_port"],
          item["to_port"],
          item["protocol"],
          join("|", coalesce(item["cidr_blocks"], [])),
          coalesce(item["description"], " "),
          join("|", tolist(coalesce(item["ipv6_cidr_blocks"], []))),
          join("|", tolist(coalesce(item["prefix_list_ids"], []))),
          coalesce(item["source_security_group_id"], " "),
          item["self"] == null ? " " : tostring(item["self"]),
        )
      )
    ) => item
  }

  type                     = "egress"
  from_port                = each.value["from_port"]
  to_port                  = each.value["to_port"]
  protocol                 = each.value["protocol"]
  cidr_blocks              = each.value["cidr_blocks"]
  description              = each.value["description"]
  ipv6_cidr_blocks         = each.value["ipv6_cidr_blocks"]
  prefix_list_ids          = each.value["prefix_list_ids"]
  source_security_group_id = each.value["source_security_group_id"]
  self                     = each.value["self"]
  security_group_id        = aws_security_group.security_group[each.value.sg_name].id
}
