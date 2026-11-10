# Sample values. No identifiers of real resources and no secrets.
client      = "fnc"
project     = "aroma"
environment = "dev"
region      = "us-east-1"

vpc_cidr           = "10.50.0.0/16"
availability_zones = ["us-east-1a"]

# Billed items stay off.
enable_private_endpoints = false

# Placeholder identifiers for a validation run. A real root passes the outputs of the security module.
flow_logs_role_arn    = "arn:aws:iam::123456789012:role/fnc-aroma-dev-role-flow-logs"
flow_logs_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "dev"
  Owner       = "platform"
  CostCenter  = "pruebas"
  ManagedBy   = "Terraform"
}
