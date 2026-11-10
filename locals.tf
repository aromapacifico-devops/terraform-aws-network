# Local values and transformations of the module.
locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"

  # Subnets of these purposes receive the routes to the collection centers. The others stay without them.
  center_route_purposes = ["telemetry-ingress", "drone-ingress", "application"]

  route_table_of = {
    for key, subnet in var.subnets :
    key => contains(local.center_route_purposes, subnet.purpose) ? "private_center" : "private"
  }

  route_table_names = {
    private        = "${local.name_prefix}-rt-private"
    private_center = "${local.name_prefix}-rt-private-center"
  }

  gateway_endpoints = {
    s3       = "com.amazonaws.${data.aws_region.current.region}.s3"
    dynamodb = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  }

  interface_endpoints = var.enable_private_endpoints ? {
    iot_data    = { service = "iot.data", purpose = "telemetry-ingress" }
    s3          = { service = "s3", purpose = "drone-ingress" }
    private_api = { service = "execute-api", purpose = "application" }
  } : {}
}
