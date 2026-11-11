# terraform-aws-network

Network of one Aroma Pacifico environment. The module builds the VPC, its seven subnet purposes, the route tables, the free gateway endpoints and, when asked, the private interface endpoints and the VPN link to the collection centers. Test and production use the same code with different variables, and a new availability zone adds one entry per purpose to one variable. It implements the VPC, subnet and route boxes of the implementation scope, and the box C04, the link to a collection center, which is built only when a center is given in `center_links`.

## Why this network exists

The workload is serverless, so most services run outside the VPC. The VPC exists for one reason, the private path from the collection centers to the platform. Farms reach public service endpoints and need nothing from this module. For that reason the VPC has no internet gateway and no NAT gateway.

## What it creates

| Resource | Purpose |
|---|---|
| VPC | One per environment, in a /16 range, with DNS support and no internet gateway or NAT gateway |
| Subnets | One per purpose and availability zone. Seven purposes, so seven subnets with one zone and fourteen with two |
| Route tables | `private_center` for the telemetry ingress, drone object ingress and application subnets, and `private` for the data, object storage, administration and public query subnets |
| Gateway endpoints | Free private paths to S3 and DynamoDB, attached to both route tables |
| Interface endpoints | IoT Core data in the telemetry ingress subnets, S3 in the drone object ingress subnets and the private API in the application subnets. One endpoint per service, with a network interface in each zone of its subnet. Created only when `enable_private_endpoints` is true |
| Flow log and log group | Records all accepted and rejected traffic of the VPC in an encrypted CloudWatch log group, kept 365 days by default. Created only when `enable_flow_logs` is true |
| Virtual private gateway, customer gateway, VPN connection and static routes | One gateway for the environment, and one customer gateway, one connection and two static routes for each center in `center_links`. Created only when that map is not empty |
| Routes toward the centers | Two routes for each center in the table `private_center`, `10.X.3.0/24` and `10.X.10.0/24`, with the gateway as target. Nothing in the table `private` |
| Default security group | The default group of the VPC is adopted with no rules, so no resource can use it by accident. The module creates no other security group |

The seven purposes are telemetry ingress, drone object ingress, application, data, object storage, administration and public query. Three of them hold an interface endpoint today, and four stay reserved so that a later component lands in its place with no renumbering.

The two route tables only decide which subnets can receive routes to the collection centers later. Access depends on the security groups, the endpoint policies and IAM.

## What it leaves to other modules

| Need | Comes from |
|---|---|
| Security groups of the interface endpoints | Security module, through `endpoint_security_group_ids` |
| Encryption keys, including the key of the flow log group | Security module, through `flow_logs_kms_key_arn` |
| Role the flow log service assumes | Security module, through `flow_logs_role_arn` |
| Final resource names | The root, which builds them from the naming convention |

The security groups need the VPC, and the endpoints need the security groups. Both modules live in one root, and Terraform orders that dependency per resource, so the two modules reference each other with no cycle.

## Address plan

Each purpose takes a /20 block, and each availability zone inside it takes a /24. The second octet alone identifies the environment.

| Environment | Range | Availability zones |
|---|---|---|
| Development | 10.50.0.0/16 | One |
| Test | 10.60.0.0/16 | One |
| Production | 10.70.0.0/16 | Two |

| Purpose | Block in production | Zone a | Zone b |
|---|---|---|---|
| Telemetry ingress | 10.70.0.0/20 | 10.70.0.0/24 | 10.70.1.0/24 |
| Drone object ingress | 10.70.16.0/20 | 10.70.16.0/24 | 10.70.17.0/24 |
| Application | 10.70.32.0/20 | 10.70.32.0/24 | 10.70.33.0/24 |
| Data | 10.70.48.0/20 | 10.70.48.0/24 | 10.70.49.0/24 |
| Object storage | 10.70.64.0/20 | 10.70.64.0/24 | 10.70.65.0/24 |
| Administration | 10.70.80.0/20 | 10.70.80.0/24 | 10.70.81.0/24 |
| Public query | 10.70.96.0/20 | 10.70.96.0/24 | 10.70.97.0/24 |

The ranges 10.41.0.0/16, 10.42.0.0/16 and 10.43.0.0/16 belong to Cauca, Huila and Tolima, so a validation rejects any VPC range that overlaps them.

## Center link

The link is a site-to-site VPN on a virtual private gateway, with static routing and two tunnels for each connection, as the design of the center to cloud link states. It is built from `center_links`, a map keyed by the department code, `"41"` Cauca, `"42"` Huila or `"43"` Tolima. Each entry has a short `name` and the static `public_ip` of the center firewall. The module derives the two ranges of the center from the code, so the department is chosen by a variable and no code is copied.

| Setting | Value |
|---|---|
| Routing | Static, with the two ranges of the center as the static routes of its connection |
| Tunnels | IKEv2 only, AWS starts both, DPD timeout of 30 seconds with the action `restart`. The 30 seconds is a detection time and not a recovery time |
| Keys | Stored in AWS Secrets Manager, `preshared_key_storage = "SecretsManager"`. The module sets no key, creates no secret of its own and exposes no key. It exports the ARN of the secret, which is a name |
| Customer gateway ASN | A placeholder of 65000, which matters only for dynamic routing and is not used |
| Traffic selectors, algorithms and lifetimes | The AWS defaults, to set when the firewall of the center is chosen |

The module does not read, create or show a key, and its tests never read a secret value.

### Routing and authorization

The routes give a path and nothing else. Only the logistics range `10.X.3.0/24` and the local servers range `10.X.10.0/24` of each center are routed, and only in `private_center`, the table of the subnets that hold the endpoints. The Management, Support, Transport and Visitors ranges and the range of the firewall have no route, and nothing is routed in `private`. This is narrower than a route to the whole `10.4X.0.0/16`, on purpose. What may pass over a route is decided by the security groups of the endpoints, the network ACLs, the firewall of the center and the policies of each service, which this module does not touch.

### Activation and addresses

The module links the centers that are in `center_links` and nothing else, so an empty map creates no VPN resource. The root decides which centers to request. The root of this repository set passes only the centers in `linked_centers`, requires a valid address for every one of them when `enable_center_link` is true, makes the plan fail when one is missing, and rejects an address for a center that was not requested. A center is never skipped without a message.

The addresses of the range 203.0.113.0/24 appear only in the examples and the tests, and they are demonstration values. They are not the address of a real center and must not be applied. A real address is the static address that the provider of each center assigns.

### Compatibility

The variable has the default `{}` and the link outputs are empty without a link, so a caller of 1.0.0 that passes no `center_links` gets the same network. The plan of the existing tests holds the same resources, the route tables carry no inline route, and the module needs no new provider. The new outputs of the interface endpoints list facts of the endpoints and exist whenever the endpoints do. A plan against the real state of an existing environment has not been run for this release, so it is not claimed to show no change until someone runs it.

### Tests and what they prove

The tests run on a mocked provider. They prove the plan logic of this module, which are the resources and routes for no, one and three centers, the isolation of the routes, the validation of every input, the tunnel parameters, and that the module sets and exposes no key. They do not prove that AWS accepts the resources, that a tunnel comes up or that a center reaches a service. A real plan in an account shows the association in that account, and a connection test needs the firewall of a center. Both are separate from these tests.

### What the link does not cover

The link carries traffic and does not make every service work. Whether IoT Core data takes TCP 443 or 8883 through its endpoint, which host the upload function signs for S3, and the names that a center uses for each service are open in the design of the link and are not part of this module. The module only outputs the endpoint names and interface identifiers. Nothing here shows that a center reaches IoT Core, S3 or the private API.

## Usage

Use the latest released tag in place of `v1.0.0`.

```hcl
module "network" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-network.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  vpc_name                    = local.vpc_name
  vpc_cidr                    = var.vpc_cidr
  subnets                     = local.subnets
  endpoint_security_group_ids = module.security.endpoint_security_group_ids
  enable_private_endpoints    = var.enable_private_endpoints
}
```

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment`, `additional_tags` | Governance | See below | Codes for names and tags, and the extra tags of the module. `additional_tags` is optional |
| `vpc_name` | `string` | Yes | Final name of the VPC |
| `vpc_cidr` | `string` | Yes | Range of the VPC, a /16 written from its network address. It cannot be 10.41.0.0/16, 10.42.0.0/16 or 10.43.0.0/16 |
| `subnets` | `map(object)` | Yes | Name, purpose, range and availability zone of each subnet, keyed by purpose and zone such as `telemetry-ingress-a`. It must hold all seven purposes, one subnet per purpose and zone, inside `vpc_cidr` and without overlaps |
| `endpoint_security_group_ids` | `map(string)` | Yes | Security group of each interface endpoint, keyed `iot_data`, `s3` and `private_api`. It can be empty while `enable_private_endpoints` is false |
| `enable_private_endpoints` | `bool` | No | Creates the interface endpoints. Defaults to `false` |
| `center_links` | `map(object)` | No | Collection centers to link, keyed by department code 41, 42 or 43, each with `name` and a public `public_ip`. Defaults to `{}`, which creates no VPN resource. The keys, the names, the addresses and their uniqueness are validated |
| `enable_flow_logs` | `bool` | No | Creates the log group and the flow log. Defaults to `false` |
| `flow_logs_log_group_name` | `string` | When flow logs are on | Name of the log group, built by the root |
| `flow_logs_role_arn` | `string` | When flow logs are on | Role that the flow log service assumes to write to the group |
| `flow_logs_kms_key_arn` | `string` | When flow logs are on | Key that encrypts the group |
| `flow_logs_retention_days` | `number` | No | Retention of the group. Defaults to 365, and only the values from 365 up that CloudWatch Logs accepts are valid |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `subnet_ids` | IDs of the subnets, keyed like `subnets` |
| `route_table_ids` | IDs of the route tables, keyed `private` and `private_center` |
| `vpn_gateway_id` | ID of the virtual private gateway, or null when no center is linked |
| `center_link_connection_ids` | ID of the VPN connection of each linked center, keyed by department code |
| `center_link_tunnel_addresses` | The two outside addresses of the tunnels of each linked center, for the firewall of the center |
| `center_link_secret_arns` | ARN of the Secrets Manager secret that holds the keys of each linked center. It is a name and not a key |
| `center_link_routes` | The two ranges routed toward each linked center |
| `interface_endpoint_dns_names` | Endpoint-specific DNS names of each interface endpoint, empty while the endpoints are off |
| `interface_endpoint_network_interface_ids` | Network interface IDs of each interface endpoint, empty while the endpoints are off |
| `flow_log_group_arn` | ARN of the flow log group, or null when flow logs are off |
| `flow_log_id` | ID of the flow log, or null when flow logs are off |

## Flow logs

Flow logs stay off by default. They need a role that the flow log service assumes and a key for the log group, and the security module provides neither today. While they are off, every plan warns that the VPC keeps no record of its traffic.

When `enable_flow_logs` is true, the flow log records every accepted and rejected connection of the network interfaces in the VPC, which today are the interface endpoints. The log group is encrypted with the received key and keeps 365 days by default. The module rejects shorter values, so a shorter retention needs a change to the module itself.

The root builds the log group name and passes the same name to the security module, which writes it into the key policy and the role policy. The security module must not read `flow_log_group_arn` from this module. The log group needs the key, and a key policy that waits for the log group would close a loop, which Terraform reports as a cycle.

The creation order the module expects, resource by resource, is the role, then the key and its policy, which names that role, then the log group, then the flow log. The role resource itself must not depend on the key, so a policy that names the key has to be a separate resource attached to the role, and no inline policy inside the role resource may do it. The VPC, the endpoint security groups and the interface endpoints form a separate chain.

The module tests run on a mocked provider and prove the plan of this module only. A stand-in security module that follows this contract, combined with this module in a local root, builds its dependency graph with no cycle, and the same root with the forbidden read of `flow_log_group_arn` fails with a cycle. The stand-in is not the real security module, and nothing here shows that the flow logs reach the log group, that the role and key policies are accepted, or that the encryption works. Those need the real security module in a plan and a deployment.

## Cost

Only the interface endpoints bill by the hour, and `enable_private_endpoints` turns them off for work sessions that do not need them.

| Item | Rate | Variable |
|---|---|---|
| One interface endpoint in one zone | USD 0.01 per hour | `enable_private_endpoints` |
| One VPN connection | USD 0.05 per hour, USD 36.50 a month | `center_links`, one for each linked center |
| One secret of pre-shared keys | USD 0.40 a month, one for each connection | `center_links` |

The VPC, the subnets, the route tables and the gateway endpoints have no hourly charge.

Flow logs, when they are on, bill by volume. CloudWatch Logs charges USD 0.50 per GB ingested for vended logs in the first 10 TB, and USD 0.03 per GB a month of storage, in us-east-1 and from the AWS Price List API. The volume has not been measured, so the figures below are scenarios. A traffic of 1 GB a month costs about USD 0.50 a month to ingest. Storage accumulates until the retention is reached, so after a year the stored data is up to twelve times one month, about USD 0.36 a month in that scenario, before any compression. A traffic of 5 GB a month reaches about USD 2.50 of ingestion and USD 1.80 of storage. Higher traffic costs proportionally more. The key that encrypts the group is billed by the security module, USD 1 a month for each key that exists. Three endpoints in two zones create six network interfaces, which is USD 0.06 per hour at that rate.

## Develop and test

The exact Terraform version lives in `.terraform-version`. Tests run against a mocked provider, so they need no AWS account and spend no credits.

```bash
terraform init -backend=false
terraform test
terraform -chdir=sample init -backend=false
terraform -chdir=sample validate
```

`terraform validate` runs on `sample/` because this module declares the `aws.project` provider alias, which only receives a provider from a caller.

The shared checks of the organization cover format, tests, TFLint, Checkov and secret scanning. An accepted finding goes in `docs/iac-exceptions.md` with its reason and its end condition.

## Versions

Commits follow Conventional Commits, and they decide the next version. A `fix` raises the patch, a `feat` raises the minor, and a breaking change raises the major. Each release publishes an exact `vX.Y.Z` tag and updates `CHANGELOG.md`. Consumers pin that tag, so a new version reaches an environment only through a reviewed change in the infrastructure repository.

## Related repositories

| Repository | Role |
|---|---|
| [`aromapacifico-devops-infra`](https://github.com/aromapacifico-devops/aromapacifico-devops-infra) | Roots of each environment, which consume this module |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Template this repository was generated from |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
