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

variable "enable_flow_logs" {
  description = "Records the traffic of the VPC in an encrypted log group. It needs the role and the key from the security module, so it stays off until that module provides them."
  type        = bool
  default     = false
}

variable "flow_logs_log_group_name" {
  description = "Name of the log group that receives the flow logs. The root builds it and passes the same name to the module that creates the key and the role, so neither depends on the output of this module."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_flow_logs || can(regex("^[./#_A-Za-z0-9-]{1,512}$", var.flow_logs_log_group_name))
    error_message = "flow_logs_log_group_name must be 1 to 512 characters of letters, digits and ./#_- when enable_flow_logs is true."
  }
}

variable "flow_logs_role_arn" {
  description = "Role that the flow log service assumes to write to the log group. It comes from the security module."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_flow_logs || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.flow_logs_role_arn))
    error_message = "flow_logs_role_arn must be an IAM role ARN when enable_flow_logs is true."
  }
}

variable "flow_logs_kms_key_arn" {
  description = "Key that encrypts the log group. It comes from the security module."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_flow_logs || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.flow_logs_kms_key_arn))
    error_message = "flow_logs_kms_key_arn must be a KMS key ARN when enable_flow_logs is true."
  }
}

variable "flow_logs_retention_days" {
  description = "Days the log group keeps the records. The project keeps a year or more. CloudWatch Logs accepts only fixed values."
  type        = number
  default     = 365

  validation {
    condition     = contains([365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days must be 365 or a longer retention value that CloudWatch Logs accepts, up to 3653."
  }
}

variable "center_links" {
  description = "Collection centers linked to this environment, keyed by department code, 41 Cauca, 42 Huila or 43 Tolima. Each entry holds a short name and the static public address of the center firewall. The module derives 10.X.3.0/24 and 10.X.10.0/24 from the code and routes only those two ranges. An empty map, the default, creates no VPN resource."
  type = map(object({
    name      = string
    public_ip = string
  }))
  default = {}

  validation {
    condition     = alltrue([for code in keys(var.center_links) : contains(["41", "42", "43"], code)])
    error_message = "center_links keys must be the department codes 41, 42 or 43."
  }

  validation {
    condition     = alltrue([for link in values(var.center_links) : can(regex("^[a-z][a-z0-9-]{1,19}$", link.name))])
    error_message = "Each center name must be 2 to 20 lowercase letters, digits or hyphens, starting with a letter."
  }

  validation {
    condition     = alltrue([for link in values(var.center_links) : can(cidrhost("${link.public_ip}/32", 0))])
    error_message = "Each public_ip must be a valid IPv4 address."
  }

  validation {
    condition = alltrue([
      for link in values(var.center_links) :
      !anytrue([for range in ["0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12", "192.168.0.0/16", "224.0.0.0/4", "240.0.0.0/4"] : try(cidrhost("${link.public_ip}/${split("/", range)[1]}", 0) == split("/", range)[0], true)])
    ])
    error_message = "Each public_ip must be a public address, not private, shared, loopback, link-local, multicast or reserved."
  }

  validation {
    condition     = length(distinct([for link in values(var.center_links) : link.public_ip])) == length(var.center_links)
    error_message = "Each center needs its own public_ip."
  }
}
