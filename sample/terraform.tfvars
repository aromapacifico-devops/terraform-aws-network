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

# No center is linked. The next lines show the form with a demonstration address of the 203.0.113.0/24 documentation range.
# It is not a real center and must never be applied.
# center_links = {
#   "41" = { name = "cauca", public_ip = "203.0.113.10" }
# }
