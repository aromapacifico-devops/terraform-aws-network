# Outputs of the module. Each one exposes a single attribute and has a description.
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "IDs of the subnets, keyed like the subnets variable."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "route_table_ids" {
  description = "IDs of the route tables, keyed private and private_center."
  value       = { for key, table in aws_route_table.this : key => table.id }
}

output "flow_log_group_arn" {
  description = "ARN of the log group that receives the flow logs, or null when flow logs are off."
  value       = one(aws_cloudwatch_log_group.flow_logs[*].arn)
}

output "flow_log_id" {
  description = "ID of the flow log, or null when flow logs are off."
  value       = one(aws_flow_log.this[*].id)
}

output "vpn_gateway_id" {
  description = "ID of the virtual private gateway, or null when no center is linked."
  value       = one(aws_vpn_gateway.this[*].id)
}

output "center_link_connection_ids" {
  description = "ID of the VPN connection of each linked center, keyed by department code."
  value       = { for code, connection in aws_vpn_connection.this : code => connection.id }
}

output "center_link_tunnel_addresses" {
  description = "Outside addresses of the two tunnels of each linked center, keyed by department code, for the rules and the configuration of the center firewall."
  value       = { for code, connection in aws_vpn_connection.this : code => { tunnel1 = connection.tunnel1_address, tunnel2 = connection.tunnel2_address } }
}

output "center_link_secret_arns" {
  description = "ARN of the Secrets Manager secret that holds the pre-shared keys of each linked center. It is the name of the secret and not a key. The keys are never an output."
  value       = { for code, connection in aws_vpn_connection.this : code => connection.preshared_key_arn }
}

output "center_link_routes" {
  description = "Routes toward each linked center in the table private_center, keyed by department code, and the same ranges that the center announces in the static routes of its connection."
  value       = { for code, link in var.center_links : code => ["10.${code}.${local.center_zones["logistics"]}.0/24", "10.${code}.${local.center_zones["local-servers"]}.0/24"] }
}

output "interface_endpoint_dns_names" {
  description = "Endpoint-specific DNS names of each interface endpoint, keyed iot_data, s3 and private_api. Empty while enable_private_endpoints is false."
  value       = { for key, endpoint in aws_vpc_endpoint.interface : key => [for entry in endpoint.dns_entry : entry.dns_name] }
}

output "interface_endpoint_network_interface_ids" {
  description = "Network interface IDs of each interface endpoint, keyed iot_data, s3 and private_api. Empty while enable_private_endpoints is false."
  value       = { for key, endpoint in aws_vpc_endpoint.interface : key => sort(tolist(endpoint.network_interface_ids)) }
}
