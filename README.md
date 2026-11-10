# terraform-aws-network

Network of one Aroma Pacifico environment. The module builds the VPC, its seven subnet purposes, the route tables, the free gateway endpoints and, when asked, the private interface endpoints. Test and production use the same code with different variables, and a new availability zone adds one entry per purpose to one variable. It implements the VPC, subnet and route boxes of the implementation scope.

The link to each collection center, with its virtual private gateway and routes, arrives in a later release and is not part of this one.

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
| Default security group | The default group of the VPC is adopted with no rules, so no resource can use it by accident. The module creates no other security group |

The seven purposes are telemetry ingress, drone object ingress, application, data, object storage, administration and public query. Three of them hold an interface endpoint today, and four stay reserved so that a later component lands in its place with no renumbering.

The two route tables only decide which subnets can receive routes to the collection centers later. They are not an access control. Who can reach what depends on the security groups, the endpoint policies and IAM.

## What it leaves to other modules

| Need | Comes from |
|---|---|
| Security groups of the interface endpoints | Security module, through `endpoint_security_group_ids` |
| Encryption keys | Security module |
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

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `subnet_ids` | IDs of the subnets, keyed like `subnets` |
| `route_table_ids` | IDs of the route tables, keyed `private` and `private_center` |

## Cost

Only the interface endpoints bill by the hour, and `enable_private_endpoints` turns them off for work sessions that do not need them.

| Item | Rate | Variable |
|---|---|---|
| One interface endpoint in one zone | USD 0.01 per hour | `enable_private_endpoints` |

The VPC, the subnets, the route tables and the gateway endpoints have no hourly charge. Three endpoints in two zones create six network interfaces, which is USD 0.06 per hour at that rate.

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
