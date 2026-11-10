# Input variables of the module.
variable "client" {
  description = "Client code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.client))
    error_message = "client must be 1 to 10 lowercase alphanumeric characters."
  }
}

variable "project" {
  description = "Project code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,15}$", var.project))
    error_message = "project must be 1 to 15 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "additional_tags" {
  description = "Tags added to the resources of this module, on top of the provider default tags."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.additional_tags) : length(trimspace(key)) > 0])
    error_message = "additional_tags keys cannot be empty."
  }
}

variable "vpc_name" {
  description = "Final name of the VPC, built by the root from the naming convention."
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_name)) > 0
    error_message = "vpc_name cannot be empty."
  }
}

variable "vpc_cidr" {
  description = "Range of the VPC, a /16 written from its network address that overlaps no collection center."
  type        = string

  validation {
    condition     = try(split("/", var.vpc_cidr)[1] == "16" && cidrhost(var.vpc_cidr, 0) == split("/", var.vpc_cidr)[0], false)
    error_message = "vpc_cidr must be a /16 written from its network address, such as 10.60.0.0/16."
  }

  validation {
    condition     = !contains(["10.41.0.0/16", "10.42.0.0/16", "10.43.0.0/16"], var.vpc_cidr)
    error_message = "vpc_cidr cannot overlap 10.41.0.0/16, 10.42.0.0/16 or 10.43.0.0/16, which belong to the collection centers."
  }
}

variable "subnets" {
  description = "Subnets of the VPC, keyed by purpose and zone, such as telemetry-ingress-a. Each one has a name, a purpose, a range and an availability zone."
  type = map(object({
    name              = string
    purpose           = string
    cidr              = string
    availability_zone = string
  }))

  validation {
    condition = alltrue([
      for subnet in values(var.subnets) : contains(
        ["telemetry-ingress", "drone-ingress", "application", "data", "object-storage", "administration", "public-query"],
        subnet.purpose
      )
    ])
    error_message = "Each subnet purpose must be telemetry-ingress, drone-ingress, application, data, object-storage, administration or public-query."
  }

  validation {
    condition = alltrue([
      for purpose in ["telemetry-ingress", "drone-ingress", "application", "data", "object-storage", "administration", "public-query"] :
      anytrue([for subnet in values(var.subnets) : subnet.purpose == purpose])
    ])
    error_message = "subnets must hold at least one subnet for each of the seven purposes."
  }

  validation {
    condition     = length(distinct([for subnet in values(var.subnets) : "${subnet.purpose}/${subnet.availability_zone}"])) == length(var.subnets)
    error_message = "Each purpose can have only one subnet per availability zone."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.subnets) : try(
        tonumber(split("/", subnet.cidr)[1]) >= 17 && tonumber(split("/", subnet.cidr)[1]) <= 28 &&
        cidrhost(subnet.cidr, 0) == split("/", subnet.cidr)[0] &&
        join(".", slice(split(".", subnet.cidr), 0, 2)) == join(".", slice(split(".", var.vpc_cidr), 0, 2)),
        false
      )
    ])
    error_message = "Each subnet range must be a valid block between /17 and /28 written from its network address, inside vpc_cidr."
  }

  validation {
    condition = try(alltrue([
      for a, first in var.subnets : alltrue([
        for b, second in var.subnets : a == b || (
          (tonumber(split(".", cidrhost(first.cidr, -1))[2]) * 256 + tonumber(split(".", cidrhost(first.cidr, -1))[3])) <
          (tonumber(split(".", cidrhost(second.cidr, 0))[2]) * 256 + tonumber(split(".", cidrhost(second.cidr, 0))[3])) ||
          (tonumber(split(".", cidrhost(second.cidr, -1))[2]) * 256 + tonumber(split(".", cidrhost(second.cidr, -1))[3])) <
          (tonumber(split(".", cidrhost(first.cidr, 0))[2]) * 256 + tonumber(split(".", cidrhost(first.cidr, 0))[3]))
        )
      ])
    ]), false)
    error_message = "Subnet ranges cannot overlap each other."
  }
}

variable "endpoint_security_group_ids" {
  description = "Security group of each interface endpoint, keyed iot_data, s3 and private_api. The module creates no security group and accepts an empty map while enable_private_endpoints is false."
  type        = map(string)

  validation {
    condition     = !var.enable_private_endpoints || alltrue([for key in ["iot_data", "s3", "private_api"] : contains(keys(var.endpoint_security_group_ids), key)])
    error_message = "endpoint_security_group_ids must hold iot_data, s3 and private_api when enable_private_endpoints is true."
  }
}

variable "enable_private_endpoints" {
  description = "Creates the interface endpoints, which bill by the hour. The free gateway endpoints are always created."
  type        = bool
  default     = false
}
