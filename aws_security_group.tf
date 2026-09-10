#
# Create security gropus for the current VPC
#
resource "aws_security_group" "security_group" {
  for_each = {
    for sg in var.vpc_config.security_groups :
    sg.name => (
      var.vpc_config["vpc"]["vpc_id"] != null ? merge(
        sg,
        tomap(
          {
            vpc_id = var.vpc_config["vpc"]["vpc_id"]
          }
        )
      ) : sg
    )
  }

  name        = each.value.name_prefix == null ? each.value.name : null
  name_prefix = each.value.name_prefix
  description = each.value.description

  vpc_id = try(
    aws_vpc.vpc["vpc"].id,
    each.value.vpc_id,
    var.vpc_config.vpc.vpc_id
  )

  revoke_rules_on_delete = each.value.revoke_rules_on_delete
  tags = merge(
    local.common_tags,
    each.value.tags,
    tomap(
      {
        "Name" = upper(
          format(
            "sg-%s",
            coalesce(
              try(each.value.name, null),
              try(lookup(var.vpc_config.global.tags, "stack", ""), null),
              "terraform-created"
            )
          )
        )
      }
    )
  )
}

