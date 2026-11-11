# Changelog

## [Unreleased]

### Added

- Optional variable `center_links`, a map keyed by department code 41, 42 or 43 with the name and the static public address of each center. An empty map, the default, creates no VPN resource.
- A virtual private gateway, a customer gateway, a VPN connection with static routing and two static routes for each linked center, with the keys in Secrets Manager and no key set or exposed by the module.
- Two routes toward each linked center in `private_center`, `10.X.3.0/24` and `10.X.10.0/24`, and none in `private`.
- Outputs `vpn_gateway_id`, `center_link_connection_ids`, `center_link_tunnel_addresses`, `center_link_secret_arns` and `center_link_routes` for the link, and `interface_endpoint_dns_names` and `interface_endpoint_network_interface_ids` for the endpoints.

## [1.0.0] - 2026-11-10

### Added

- VPC of one environment with DNS support and no internet or NAT gateway. Its default security group is adopted with no rules.
- One subnet per purpose and availability zone for the seven purposes, with validations for the range, the containment in the VPC, overlaps and the collection center ranges.
- Route tables `private` and `private_center`, and gateway endpoints for S3 and DynamoDB attached to both.
- Interface endpoints for IoT Core data, S3 and the private API when `enable_private_endpoints` is true, with the security groups received in `endpoint_security_group_ids`.
- Flow log to an encrypted CloudWatch log group when `enable_flow_logs` is true. It is off by default.

### Changed

- `vpc_name`, `vpc_cidr`, `subnets` and `endpoint_security_group_ids` are required inputs, so callers of 0.1.0 must pass them.
