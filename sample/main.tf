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
  center_links                = var.center_links

  enable_flow_logs         = var.enable_flow_logs
  flow_logs_log_group_name = local.flow_logs_log_group_name
  flow_logs_role_arn       = var.flow_logs_role_arn
  flow_logs_kms_key_arn    = var.flow_logs_kms_key_arn
  flow_logs_retention_days = var.flow_logs_retention_days
}
