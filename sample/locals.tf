# Transformations of the sample. The final resource names and the payload of the module are built here.
locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"
  vpc_name    = "${local.name_prefix}-vpc-main"

  purposes = ["telemetry-ingress", "drone-ingress", "application", "data", "object-storage", "administration", "public-query"]
  octet    = split(".", var.vpc_cidr)[1]

  # Each purpose takes a /20 block, and each zone inside it takes a /24.
  subnets = merge([
    for purpose_index, purpose in local.purposes : {
      for zone_index, zone in var.availability_zones :
      "${purpose}-${substr(zone, -1, 1)}" => {
        name              = "${local.name_prefix}-subnet-${purpose}-${substr(zone, -1, 1)}"
        purpose           = purpose
        cidr              = "10.${local.octet}.${purpose_index * 16 + zone_index}.0/24"
        availability_zone = zone
      }
    }
  ]...)
}
