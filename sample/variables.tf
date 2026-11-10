# Input variables of the sample.
variable "client" {
  description = "Client code."
  type        = string
}

variable "project" {
  description = "Project code."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "region" {
  description = "AWS Region of the sample."
  type        = string
}

variable "deploy_role_arn" {
  description = "Role to assume. Leave empty to use the local credentials."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider."
  type        = map(string)
}

variable "vpc_cidr" {
  description = "Range of the VPC, a /16 outside the collection center ranges."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones of the sample. Each purpose gets one subnet per zone."
  type        = list(string)
}

variable "enable_private_endpoints" {
  description = "Creates the interface endpoints, which bill by the hour."
  type        = bool
  default     = false
}

variable "endpoint_security_group_ids" {
  description = "Security group of each interface endpoint. Leave empty while enable_private_endpoints is false."
  type        = map(string)
  default     = {}
}

variable "enable_flow_logs" {
  description = "Records the traffic of the VPC in an encrypted log group."
  type        = bool
  default     = true
}

variable "flow_logs_role_arn" {
  description = "Role of the flow log service. In a real root it comes from the security module."
  type        = string
}

variable "flow_logs_kms_key_arn" {
  description = "Key of the log group. In a real root it comes from the security module."
  type        = string
}

variable "flow_logs_retention_days" {
  description = "Days the log group keeps the records."
  type        = number
  default     = 365
}
