# Changelog

## [Unreleased]

## [1.0.0] - 2026-11-10

### Added

- VPC of one environment with DNS support and no internet or NAT gateway. Its default security group is adopted with no rules.
- One subnet per purpose and availability zone for the seven purposes, with validations for the range, the containment in the VPC, overlaps and the collection center ranges.
- Route tables `private` and `private_center`, and gateway endpoints for S3 and DynamoDB attached to both.
- Interface endpoints for IoT Core data, S3 and the private API when `enable_private_endpoints` is true, with the security groups received in `endpoint_security_group_ids`.
- Flow log to an encrypted CloudWatch log group when `enable_flow_logs` is true. It is off by default.

### Changed

- `vpc_name`, `vpc_cidr`, `subnets` and `endpoint_security_group_ids` are required inputs, so callers of 0.1.0 must pass them.
