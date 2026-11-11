# Tests of the center link against a mocked provider. They need no AWS account and create nothing.
# The addresses of the 203.0.113.0/24 documentation range are demonstration values, not real centers.
mock_provider "aws" {
  alias = "project"

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/vpc/fnc-aroma-test-vpc-main/flow-logs"
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

  enable_flow_logs         = true
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

run "no_link_by_default_creates_no_vpn_resource" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = (
      length(aws_vpn_gateway.this) == 0 && length(aws_customer_gateway.this) == 0 && length(aws_vpn_connection.this) == 0 &&
      length(aws_vpn_connection_route.this) == 0 && length(aws_route.center) == 0
    )
    error_message = "With no center linked the module must create no VPN resource and no route to a gateway."
  }

  assert {
    condition     = length(aws_subnet.this) == 7 && length(aws_route_table.this) == 2 && length(aws_route_table_association.this) == 7
    error_message = "The network of version 1.0.0 must be unchanged when no center is linked."
  }

  assert {
    condition     = output.vpn_gateway_id == null && output.center_link_connection_ids == {} && output.center_link_routes == {}
    error_message = "The link outputs must be empty when no center is linked."
  }
}

run "one_center_creates_one_connection_and_two_routes" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "203.0.113.10" }
    }
  }

  assert {
    condition = (
      length(aws_vpn_gateway.this) == 1 && length(aws_customer_gateway.this) == 1 && length(aws_vpn_connection.this) == 1 &&
      length(aws_vpn_connection_route.this) == 2 && length(aws_route.center) == 2
    )
    error_message = "One center needs one gateway, one customer gateway, one connection, two static routes and two routes."
  }

  assert {
    condition     = toset([for route in aws_route.center : route.destination_cidr_block]) == toset(["10.41.3.0/24", "10.41.10.0/24"])
    error_message = "The cloud routes must be the logistics and local servers ranges of the center."
  }

  assert {
    condition     = toset([for route in aws_vpn_connection_route.this : route.destination_cidr_block]) == toset(["10.41.3.0/24", "10.41.10.0/24"])
    error_message = "The static routes of the connection must be the same two ranges."
  }

  assert {
    condition     = aws_customer_gateway.this["41"].ip_address == "203.0.113.10"
    error_message = "The customer gateway must use the address of the center."
  }
}

run "three_centers_create_three_connections_and_six_routes" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "203.0.113.10" }
      "42" = { name = "huila", public_ip = "203.0.113.11" }
      "43" = { name = "tolima", public_ip = "203.0.113.12" }
    }
  }

  assert {
    condition = (
      length(aws_vpn_gateway.this) == 1 && length(aws_vpn_connection.this) == 3 &&
      length(aws_vpn_connection_route.this) == 6 && length(aws_route.center) == 6
    )
    error_message = "Three centers need one gateway, three connections and six routes."
  }

  assert {
    condition     = length(distinct([for route in aws_route.center : route.destination_cidr_block])) == 6
    error_message = "No route destination may repeat."
  }
}

run "routes_are_limited_to_the_two_authorized_ranges_of_each_center" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "203.0.113.10" }
      "42" = { name = "huila", public_ip = "203.0.113.11" }
      "43" = { name = "tolima", public_ip = "203.0.113.12" }
    }
  }

  assert {
    condition     = alltrue([for route in aws_route.center : can(regex("^10\\.(41|42|43)\\.(3|10)\\.0/24$", route.destination_cidr_block))])
    error_message = "Every route must be 10.X.3.0/24 or 10.X.10.0/24 of a center."
  }

  assert {
    condition = !anytrue([
      for route in aws_route.center : anytrue([for octet in ["1", "2", "4", "5", "20"] : route.destination_cidr_block == "10.${split(".", route.destination_cidr_block)[1]}.${octet}.0/24"])
    ])
    error_message = "No route may cover the Management, Support, Transport, Visitors or firewall ranges of a center."
  }

  assert {
    condition     = alltrue([for key, route in aws_vpn_connection_route.this : startswith(route.destination_cidr_block, "10.${split("-", key)[0]}.")])
    error_message = "A connection may hold the static routes of its own center only."
  }

  assert {
    condition     = !anytrue([for route in aws_route.center : cidrhost("${split("/", route.destination_cidr_block)[0]}/16", 0) == cidrhost(var.vpc_cidr, 0)])
    error_message = "No route may point inside the VPC range."
  }

  assert {
    condition     = output.center_link_routes == { "41" = ["10.41.3.0/24", "10.41.10.0/24"], "42" = ["10.42.3.0/24", "10.42.10.0/24"], "43" = ["10.43.3.0/24", "10.43.10.0/24"] }
    error_message = "The route output must list the two ranges of each center."
  }
}

run "routes_exist_only_in_the_table_of_the_endpoint_subnets" {
  command = apply

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "203.0.113.10" }
    }
  }

  assert {
    condition     = alltrue([for route in aws_route.center : route.route_table_id == aws_route_table.this["private_center"].id])
    error_message = "Routes toward the centers belong in the table private_center."
  }

  assert {
    condition     = aws_route_table.this["private"].id != aws_route_table.this["private_center"].id
    error_message = "The table private must stay a different table, with no route toward a center."
  }
}

run "connection_uses_static_routing_ikev2_and_secrets_manager" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "203.0.113.10" }
    }
  }

  assert {
    condition     = aws_vpn_connection.this["41"].static_routes_only == true && aws_vpn_connection.this["41"].preshared_key_storage == "SecretsManager"
    error_message = "The connection must use static routes and keep its keys in Secrets Manager."
  }

  assert {
    condition = (
      contains(aws_vpn_connection.this["41"].tunnel1_ike_versions, "ikev2") && length(aws_vpn_connection.this["41"].tunnel1_ike_versions) == 1 &&
      contains(aws_vpn_connection.this["41"].tunnel2_ike_versions, "ikev2") && length(aws_vpn_connection.this["41"].tunnel2_ike_versions) == 1
    )
    error_message = "Both tunnels must allow IKEv2 only."
  }

  assert {
    condition = (
      aws_vpn_connection.this["41"].tunnel1_startup_action == "start" && aws_vpn_connection.this["41"].tunnel2_startup_action == "start" &&
      aws_vpn_connection.this["41"].tunnel1_dpd_timeout_seconds == 30 && aws_vpn_connection.this["41"].tunnel2_dpd_timeout_seconds == 30 &&
      aws_vpn_connection.this["41"].tunnel1_dpd_timeout_action == "restart" && aws_vpn_connection.this["41"].tunnel2_dpd_timeout_action == "restart"
    )
    error_message = "AWS must start both tunnels, with a DPD timeout of 30 seconds and the action restart."
  }
}

run "no_key_is_set_or_exposed_by_the_module" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_vpn_connection.this) == 0 && !strcontains(file("link.tf"), "tunnel1_preshared_key") && !strcontains(file("link.tf"), "tunnel2_preshared_key")
    error_message = "The module must not set a pre-shared key, since it would reach the state in plain text."
  }

  assert {
    condition     = length(aws_vpn_connection.this) == 0 && !strcontains(file("outputs.tf"), "tunnel1_preshared_key") && !strcontains(file("outputs.tf"), "tunnel2_preshared_key")
    error_message = "No output may carry a pre-shared key."
  }
}

run "accepts_public_addresses_next_to_the_blocked_ranges" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "172.32.0.1" }
      "42" = { name = "huila", public_ip = "100.128.0.1" }
      "43" = { name = "tolima", public_ip = "192.169.0.1" }
    }
  }

  assert {
    condition     = length(aws_vpn_connection.this) == 3
    error_message = "Public addresses just outside the blocked ranges must be accepted."
  }
}

run "rejects_a_key_that_is_not_a_department_code" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "44" = { name = "other", public_ip = "203.0.113.10" }
    }
  }

  expect_failures = [var.center_links]
}

run "rejects_a_private_address" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "10.0.0.5" }
    }
  }

  expect_failures = [var.center_links]
}

run "rejects_a_shared_address" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "100.64.1.1" }
    }
  }

  expect_failures = [var.center_links]
}

run "rejects_a_loopback_link_local_and_multicast_address" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "127.0.0.1" }
      "42" = { name = "huila", public_ip = "169.254.1.1" }
      "43" = { name = "tolima", public_ip = "224.0.0.1" }
    }
  }

  expect_failures = [var.center_links]
}

run "rejects_an_address_that_is_not_ipv4" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "not-an-address" }
    }
  }

  expect_failures = [var.center_links]
}

run "rejects_a_repeated_address" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "cauca", public_ip = "203.0.113.10" }
      "42" = { name = "huila", public_ip = "203.0.113.10" }
    }
  }

  expect_failures = [var.center_links]
}

run "rejects_an_invalid_name" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    center_links = {
      "41" = { name = "Cauca Norte", public_ip = "203.0.113.10" }
    }
  }

  expect_failures = [var.center_links]
}
