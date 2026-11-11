# Link of the environment to the collection centers. It builds nothing while center_links is empty.
# Static routing, one VPN connection for each center, and routes only to the logistics and local servers ranges.
locals {
  # Zones of a center that may use the tunnel. The second octet of the center range is its department code.
  center_zones = { logistics = 3, local-servers = 10 }

  center_routes = merge([
    for code, link in var.center_links : {
      for zone, octet in local.center_zones : "${code}-${zone}" => { code = code, cidr = "10.${code}.${octet}.0/24" }
    }
  ]...)
}

resource "aws_vpn_gateway" "this" {
  count    = length(var.center_links) > 0 ? 1 : 0
  provider = aws.project

  vpc_id = aws_vpc.this.id

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-vgw-main" })
}

# The ASN is a placeholder. It matters only for dynamic routing, which this module does not use.
resource "aws_customer_gateway" "this" {
  for_each = var.center_links
  provider = aws.project

  type       = "ipsec.1"
  ip_address = each.value.public_ip
  bgp_asn    = 65000

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-cgw-${each.value.name}", Center = each.key })
}

# The pre-shared keys stay in Secrets Manager. The module sets no key, so no key reaches a file, the state or an output.
resource "aws_vpn_connection" "this" {
  for_each = var.center_links
  provider = aws.project

  type                  = "ipsec.1"
  customer_gateway_id   = aws_customer_gateway.this[each.key].id
  vpn_gateway_id        = aws_vpn_gateway.this[0].id
  static_routes_only    = true
  preshared_key_storage = "SecretsManager"

  tunnel1_ike_versions        = ["ikev2"]
  tunnel1_startup_action      = "start"
  tunnel1_dpd_timeout_seconds = 30
  tunnel1_dpd_timeout_action  = "restart"

  tunnel2_ike_versions        = ["ikev2"]
  tunnel2_startup_action      = "start"
  tunnel2_dpd_timeout_seconds = 30
  tunnel2_dpd_timeout_action  = "restart"

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-vpn-${each.value.name}", Center = each.key })
}

# The ranges that each center announces to the cloud.
resource "aws_vpn_connection_route" "this" {
  for_each = local.center_routes

  provider = aws.project

  destination_cidr_block = each.value.cidr
  vpn_connection_id      = aws_vpn_connection.this[each.value.code].id
}

# Explicit routes toward the center ranges, only in the table of the subnets that hold endpoints.
resource "aws_route" "center" {
  for_each = local.center_routes
  provider = aws.project

  route_table_id         = aws_route_table.this["private_center"].id
  destination_cidr_block = each.value.cidr
  gateway_id             = aws_vpn_gateway.this[0].id
}
