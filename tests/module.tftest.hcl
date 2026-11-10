# Plan-time tests against a mocked provider. They need no AWS account and create nothing.
mock_provider "aws" {
  alias = "project"

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  client                      = "fnc"
  project                     = "aroma"
  environment                 = "test"
  vpc_name                    = "fnc-aroma-test-vpc-main"
  vpc_cidr                    = "10.60.0.0/16"
  endpoint_security_group_ids = {}

  flow_logs_log_group_name = "/aws/vpc/fnc-aroma-test-vpc-main/flow-logs"
  flow_logs_role_arn       = "arn:aws:iam::123456789012:role/fnc-aroma-test-role-flow-logs"
  flow_logs_kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  subnets = {
    "telemetry-ingress-a" = { name = "fnc-aroma-test-subnet-telemetry-ingress-a", purpose = "telemetry-ingress", cidr = "10.60.0.0/24", availability_zone = "us-east-1a" }
    "drone-ingress-a"     = { name = "fnc-aroma-test-subnet-drone-ingress-a", purpose = "drone-ingress", cidr = "10.60.16.0/24", availability_zone = "us-east-1a" }
    "application-a"       = { name = "fnc-aroma-test-subnet-application-a", purpose = "application", cidr = "10.60.32.0/24", availability_zone = "us-east-1a" }
    "data-a"              = { name = "fnc-aroma-test-subnet-data-a", purpose = "data", cidr = "10.60.48.0/24", availability_zone = "us-east-1a" }
    "object-storage-a"    = { name = "fnc-aroma-test-subnet-object-storage-a", purpose = "object-storage", cidr = "10.60.64.0/24", availability_zone = "us-east-1a" }
    "administration-a"    = { name = "fnc-aroma-test-subnet-administration-a", purpose = "administration", cidr = "10.60.80.0/24", availability_zone = "us-east-1a" }
    "public-query-a"      = { name = "fnc-aroma-test-subnet-public-query-a", purpose = "public-query", cidr = "10.60.96.0/24", availability_zone = "us-east-1a" }
  }
}


run "one_zone_creates_the_seven_purposes" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_subnet.this) == 7
    error_message = "One zone must produce seven subnets, one per purpose."
  }

  assert {
    condition     = length(aws_route_table.this) == 2 && length(aws_route_table_association.this) == 7
    error_message = "Expected two route tables and one association per subnet."
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.60.0.0/16"
    error_message = "The VPC must use vpc_cidr."
  }
}

run "gateway_endpoints_exist_and_interface_endpoints_do_not_by_default" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_vpc_endpoint.gateway) == 2 && length(aws_vpc_endpoint.interface) == 0
    error_message = "Only the two gateway endpoints exist while enable_private_endpoints is false."
  }

  assert {
    condition     = alltrue([for e in values(aws_vpc_endpoint.gateway) : e.vpc_endpoint_type == "Gateway"])
    error_message = "The S3 and DynamoDB endpoints must be gateway endpoints."
  }
}

run "no_security_group_is_created_besides_the_closed_default" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = aws_default_security_group.this.tags["Name"] == "fnc-aroma-test-sg-default-closed"
    error_message = "The only security group the module manages is the default one of the VPC."
  }
}

run "private_endpoints_use_the_received_security_groups" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    enable_private_endpoints = true
    endpoint_security_group_ids = {
      iot_data    = "sg-0123456789abcdef0"
      s3          = "sg-0123456789abcdef1"
      private_api = "sg-0123456789abcdef2"
    }
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 3 && length(aws_vpc_endpoint.gateway) == 2
    error_message = "Expected three interface endpoints and two gateway endpoints."
  }

  assert {
    condition     = aws_vpc_endpoint.interface["iot_data"].service_name == "com.amazonaws.us-east-1.iot.data"
    error_message = "The IoT data endpoint must use the Region of the provider."
  }

  assert {
    condition     = aws_vpc_endpoint.interface["s3"].security_group_ids == toset(["sg-0123456789abcdef1"])
    error_message = "Each endpoint receives its own security group."
  }
}

run "two_zones_create_fourteen_subnets" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    environment              = "prod"
    vpc_name                 = "fnc-aroma-prod-vpc-main"
    vpc_cidr                 = "10.70.0.0/16"
    enable_private_endpoints = true
    endpoint_security_group_ids = {
      iot_data    = "sg-0123456789abcdef0"
      s3          = "sg-0123456789abcdef1"
      private_api = "sg-0123456789abcdef2"
    }
    subnets = {
      "telemetry-ingress-a" = { name = "fnc-aroma-test-subnet-telemetry-ingress-a", purpose = "telemetry-ingress", cidr = "10.70.0.0/24", availability_zone = "us-east-1a" }
      "telemetry-ingress-b" = { name = "fnc-aroma-test-subnet-telemetry-ingress-b", purpose = "telemetry-ingress", cidr = "10.70.1.0/24", availability_zone = "us-east-1b" }
      "drone-ingress-a"     = { name = "fnc-aroma-test-subnet-drone-ingress-a", purpose = "drone-ingress", cidr = "10.70.16.0/24", availability_zone = "us-east-1a" }
      "drone-ingress-b"     = { name = "fnc-aroma-test-subnet-drone-ingress-b", purpose = "drone-ingress", cidr = "10.70.17.0/24", availability_zone = "us-east-1b" }
      "application-a"       = { name = "fnc-aroma-test-subnet-application-a", purpose = "application", cidr = "10.70.32.0/24", availability_zone = "us-east-1a" }
      "application-b"       = { name = "fnc-aroma-test-subnet-application-b", purpose = "application", cidr = "10.70.33.0/24", availability_zone = "us-east-1b" }
      "data-a"              = { name = "fnc-aroma-test-subnet-data-a", purpose = "data", cidr = "10.70.48.0/24", availability_zone = "us-east-1a" }
      "data-b"              = { name = "fnc-aroma-test-subnet-data-b", purpose = "data", cidr = "10.70.49.0/24", availability_zone = "us-east-1b" }
      "object-storage-a"    = { name = "fnc-aroma-test-subnet-object-storage-a", purpose = "object-storage", cidr = "10.70.64.0/24", availability_zone = "us-east-1a" }
      "object-storage-b"    = { name = "fnc-aroma-test-subnet-object-storage-b", purpose = "object-storage", cidr = "10.70.65.0/24", availability_zone = "us-east-1b" }
      "administration-a"    = { name = "fnc-aroma-test-subnet-administration-a", purpose = "administration", cidr = "10.70.80.0/24", availability_zone = "us-east-1a" }
      "administration-b"    = { name = "fnc-aroma-test-subnet-administration-b", purpose = "administration", cidr = "10.70.81.0/24", availability_zone = "us-east-1b" }
      "public-query-a"      = { name = "fnc-aroma-test-subnet-public-query-a", purpose = "public-query", cidr = "10.70.96.0/24", availability_zone = "us-east-1a" }
      "public-query-b"      = { name = "fnc-aroma-test-subnet-public-query-b", purpose = "public-query", cidr = "10.70.97.0/24", availability_zone = "us-east-1b" }
    }
  }

  assert {
    condition     = length(aws_subnet.this) == 14 && length(aws_route_table_association.this) == 14
    error_message = "Two zones must produce fourteen subnets."
  }

  assert {
    condition     = aws_subnet.this["telemetry-ingress-b"].cidr_block == "10.70.1.0/24" && aws_subnet.this["public-query-b"].cidr_block == "10.70.97.0/24"
    error_message = "Subnet ranges must follow the approved address plan."
  }
}

run "centers_have_no_cidr_overlap_with_the_vpc_cidr" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    vpc_cidr = "10.42.0.0/16"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_the_first_center_range" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    vpc_cidr = "10.41.0.0/16"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_a_vpc_that_is_not_a_slash_16" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    vpc_cidr = "10.60.0.0/20"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_a_subnet_outside_the_vpc" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    subnets = {
      "telemetry-ingress-a" = { name = "x", purpose = "telemetry-ingress", cidr = "10.99.0.0/24", availability_zone = "us-east-1a" }
      "drone-ingress-a"     = { name = "x", purpose = "drone-ingress", cidr = "10.60.16.0/24", availability_zone = "us-east-1a" }
      "application-a"       = { name = "x", purpose = "application", cidr = "10.60.32.0/24", availability_zone = "us-east-1a" }
      "data-a"              = { name = "x", purpose = "data", cidr = "10.60.48.0/24", availability_zone = "us-east-1a" }
      "object-storage-a"    = { name = "x", purpose = "object-storage", cidr = "10.60.64.0/24", availability_zone = "us-east-1a" }
      "administration-a"    = { name = "x", purpose = "administration", cidr = "10.60.80.0/24", availability_zone = "us-east-1a" }
      "public-query-a"      = { name = "x", purpose = "public-query", cidr = "10.60.96.0/24", availability_zone = "us-east-1a" }
    }
  }

  expect_failures = [var.subnets]
}

run "rejects_overlapping_subnets" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    subnets = {
      "telemetry-ingress-a" = { name = "x", purpose = "telemetry-ingress", cidr = "10.60.0.0/24", availability_zone = "us-east-1a" }
      "drone-ingress-a"     = { name = "x", purpose = "drone-ingress", cidr = "10.60.0.128/25", availability_zone = "us-east-1a" }
      "application-a"       = { name = "x", purpose = "application", cidr = "10.60.32.0/24", availability_zone = "us-east-1a" }
      "data-a"              = { name = "x", purpose = "data", cidr = "10.60.48.0/24", availability_zone = "us-east-1a" }
      "object-storage-a"    = { name = "x", purpose = "object-storage", cidr = "10.60.64.0/24", availability_zone = "us-east-1a" }
      "administration-a"    = { name = "x", purpose = "administration", cidr = "10.60.80.0/24", availability_zone = "us-east-1a" }
      "public-query-a"      = { name = "x", purpose = "public-query", cidr = "10.60.96.0/24", availability_zone = "us-east-1a" }
    }
  }

  expect_failures = [var.subnets]
}

run "rejects_a_missing_purpose" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    subnets = {
      "telemetry-ingress-a" = { name = "x", purpose = "telemetry-ingress", cidr = "10.60.0.0/24", availability_zone = "us-east-1a" }
    }
  }

  expect_failures = [var.subnets]
}

run "rejects_interface_endpoints_without_security_groups" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    enable_private_endpoints = true
  }

  expect_failures = [var.endpoint_security_group_ids]
}

run "flow_logs_are_on_by_default_and_use_the_received_key_and_role" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_logs) == 1 && length(aws_flow_log.this) == 1
    error_message = "One log group and one flow log are expected by default."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_logs[0].retention_in_days == 365 && aws_cloudwatch_log_group.flow_logs[0].kms_key_id == var.flow_logs_kms_key_arn
    error_message = "The log group keeps 365 days and uses the received key."
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ALL" && aws_flow_log.this[0].iam_role_arn == var.flow_logs_role_arn && aws_flow_log.this[0].log_destination_type == "cloud-watch-logs"
    error_message = "The flow log records all traffic to CloudWatch Logs with the received role."
  }
}

run "flow_logs_can_be_turned_off" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    enable_flow_logs      = false
    flow_logs_role_arn    = ""
    flow_logs_kms_key_arn = ""
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_logs) == 0 && length(aws_flow_log.this) == 0
    error_message = "No flow log resource is expected when enable_flow_logs is false."
  }

  # The plan also warns that the VPC keeps no record of its traffic.
  expect_failures = [check.flow_logs_enabled]
}

run "rejects_a_retention_below_one_year" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    flow_logs_retention_days = 90
  }

  expect_failures = [var.flow_logs_retention_days]
}

run "rejects_flow_logs_without_a_role" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    flow_logs_role_arn = ""
  }

  expect_failures = [var.flow_logs_role_arn]
}

run "rejects_flow_logs_without_a_key" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    flow_logs_kms_key_arn = "alias/logs"
  }

  expect_failures = [var.flow_logs_kms_key_arn]
}

run "rejects_an_invalid_log_group_name" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    flow_logs_log_group_name = "bad name with spaces"
  }

  expect_failures = [var.flow_logs_log_group_name]
}

run "rejects_an_unknown_environment" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "rejects_an_invalid_client_code" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    client = "FNC"
  }

  expect_failures = [var.client]
}
