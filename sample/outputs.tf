# Outputs that prove the sample worked.
output "vpc_id" {
  description = "ID of the VPC."
  value       = module.this.vpc_id
}

output "subnet_ids" {
  description = "IDs of the subnets."
  value       = module.this.subnet_ids
}

output "route_table_ids" {
  description = "IDs of the route tables."
  value       = module.this.route_table_ids
}

output "flow_log_group_arn" {
  description = "ARN of the flow log group."
  value       = module.this.flow_log_group_arn
}

output "center_link_connection_ids" {
  description = "IDs of the VPN connections, empty while no center is linked."
  value       = module.this.center_link_connection_ids
}

output "center_link_routes" {
  description = "Routes toward the linked centers in the table private_center."
  value       = module.this.center_link_routes
}
