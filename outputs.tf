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
