# Calls the module from the parent directory.
module "this" {
  source = "../"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  vpc_name                    = local.vpc_name
  vpc_cidr                    = var.vpc_cidr
  subnets                     = local.subnets
  endpoint_security_group_ids = var.endpoint_security_group_ids
  enable_private_endpoints    = var.enable_private_endpoints
}
