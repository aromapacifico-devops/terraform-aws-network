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
