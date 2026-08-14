locals {
  flow_logs_to_cloudwatch = var.vpc_config.flow_logs.create && var.vpc_config.flow_logs.log_destination_type == "cloud-watch-logs"
  flow_logs_log_group_arn = local.flow_logs_to_cloudwatch ? coalesce(
    var.vpc_config.flow_logs.log_destination_arn,
    try(aws_cloudwatch_log_group.vpc_flow_logs["vpc"].arn, null)
  ) : var.vpc_config.flow_logs.log_destination_arn
  flow_logs_iam_role_arn = local.flow_logs_to_cloudwatch ? coalesce(
    var.vpc_config.flow_logs.iam_role_arn,
    try(aws_iam_role.vpc_flow_logs["vpc"].arn, null)
  ) : var.vpc_config.flow_logs.iam_role_arn
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  for_each = local.flow_logs_to_cloudwatch && var.vpc_config.flow_logs.log_destination_arn == null ? { "vpc" = var.vpc_config.flow_logs } : {}

  name              = coalesce(each.value.cloudwatch_log_group_name, "/aws/vpc/flow-logs/${local.vpc_name_slug}-${local.vpc_context.id}")
  retention_in_days = each.value.cloudwatch_retention_in_days
  kms_key_id        = each.value.cloudwatch_kms_key_id

  tags = merge(local.common_tags, each.value.tags)
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  for_each = local.flow_logs_to_cloudwatch && var.vpc_config.flow_logs.iam_role_arn == null ? { "vpc" = var.vpc_config.flow_logs } : {}

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.session.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.session.partition}:ec2:${data.aws_region.session.region}:${data.aws_caller_identity.session.account_id}:vpc-flow-log/*"
      ]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  for_each = data.aws_iam_policy_document.vpc_flow_logs_assume_role

  name_prefix        = substr("${local.vpc_name_slug}-vpc-flow-logs-", 0, 38)
  assume_role_policy = each.value.json

  tags = merge(local.common_tags, var.vpc_config.flow_logs.tags)
}

data "aws_iam_policy_document" "vpc_flow_logs" {
  for_each = aws_iam_role.vpc_flow_logs

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["${local.flow_logs_log_group_arn}:*"]
  }

  statement {
    actions   = ["logs:DescribeLogGroups"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  for_each = aws_iam_role.vpc_flow_logs

  name_prefix = "publish-vpc-flow-logs-"
  role        = each.value.id
  policy      = data.aws_iam_policy_document.vpc_flow_logs[each.key].json
}

resource "aws_flow_log" "vpc" {
  for_each = var.vpc_config.flow_logs.create ? { "vpc" = var.vpc_config.flow_logs } : {}

  vpc_id                   = local.vpc_context.id
  traffic_type             = upper(each.value.traffic_type)
  log_destination_type     = each.value.log_destination_type
  log_destination          = local.flow_logs_log_group_arn
  iam_role_arn             = local.flow_logs_iam_role_arn
  log_format               = each.value.log_format
  max_aggregation_interval = each.value.max_aggregation_interval

  dynamic "destination_options" {
    for_each = each.value.destination_options != null ? [each.value.destination_options] : []
    content {
      file_format                = destination_options.value.file_format
      hive_compatible_partitions = destination_options.value.hive_compatible_partitions
      per_hour_partition         = destination_options.value.per_hour_partition
    }
  }

  tags = merge(local.common_tags, each.value.tags)
}
