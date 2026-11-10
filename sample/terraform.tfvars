# Sample values. No identifiers of real resources and no secrets.
client      = "fnc"
project     = "aroma"
environment = "dev"
region      = "us-east-1"

vpc_cidr           = "10.50.0.0/16"
availability_zones = ["us-east-1a"]

# Billed items stay off.
enable_private_endpoints = false

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "dev"
  Owner       = "platform"
  CostCenter  = "pruebas"
  ManagedBy   = "Terraform"
}
