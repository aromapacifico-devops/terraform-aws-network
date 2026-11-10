# Resources of the module. Every resource sets provider = aws.project.
resource "aws_vpc" "this" {
  provider = aws.project

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.additional_tags, { Name = var.vpc_name })
}

# Adopts the default security group of the VPC and removes its rules, so nothing uses it by accident.
resource "aws_default_security_group" "this" {
  provider = aws.project

  vpc_id = aws_vpc.this.id

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-sg-default-closed" })
}

resource "aws_subnet" "this" {
  for_each = var.subnets
  provider = aws.project

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.additional_tags, { Name = each.value.name, Purpose = each.value.purpose })
}

resource "aws_route_table" "this" {
  for_each = local.route_table_names
  provider = aws.project

  vpc_id = aws_vpc.this.id

  tags = merge(var.additional_tags, { Name = each.value })
}

resource "aws_route_table_association" "this" {
  for_each = var.subnets
  provider = aws.project

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[local.route_table_of[each.key]].id
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoints
  provider = aws.project

  vpc_id            = aws_vpc.this.id
  service_name      = each.value
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for table in aws_route_table.this : table.id]

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-vpce-${each.key}" })
}

# One endpoint per service. It places a network interface in each zone subnet of its purpose.
resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints
  provider = aws.project

  vpc_id             = aws_vpc.this.id
  service_name       = "com.amazonaws.${data.aws_region.current.region}.${each.value.service}"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for key, subnet in aws_subnet.this : subnet.id if var.subnets[key].purpose == each.value.purpose]
  security_group_ids = [var.endpoint_security_group_ids[each.key]]

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-vpce-${replace(each.key, "_", "-")}" })
}

# The key and the role come from the security module. The log group name is a plain input, so the key policy and
# the role policy can name the group without reading anything from this module.
resource "aws_cloudwatch_log_group" "flow_logs" {
  count    = var.enable_flow_logs ? 1 : 0
  provider = aws.project

  name              = var.flow_logs_log_group_name
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_arn

  tags = merge(var.additional_tags, { Name = var.flow_logs_log_group_name })
}

resource "aws_flow_log" "this" {
  count    = var.enable_flow_logs ? 1 : 0
  provider = aws.project

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = var.flow_logs_role_arn
  max_aggregation_interval = 600

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-flow-log" })
}

# A static scanner sees the flow log resource and passes even when the variable turns it off, so the plan warns.
check "flow_logs_enabled" {
  assert {
    condition     = var.enable_flow_logs
    error_message = "Flow logs are off, so the VPC keeps no record of its traffic."
  }
}
