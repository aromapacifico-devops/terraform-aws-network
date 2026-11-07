# terraform-aws-network

Network of one Aroma Pacifico environment. The module builds the VPC, its seven subnets, the routes, the private endpoints and the VPN link to one collection center. Test and production use the same code with different variables, and a new department adds an entry to one variable. It implements boxes C03 and C04 of the implementation scope.

This repository holds the skeleton and the interface the module commits to. The resources arrive with the first release, and no version tag exists yet.

## Why this network exists

The workload is serverless, so most services run outside the VPC. The VPC exists for one reason, the private path from the collection centers to the platform. Farms reach public service endpoints and need nothing from this module. For that reason the VPC has no internet gateway and no NAT gateway.

## What it creates

| Resource | Purpose |
|---|---|
| VPC | One per environment, in a /16 range |
| Seven subnets | Telemetry ingress, drone object ingress, application, data, object storage, administration and public query |
| Route tables | Private routes, with paths only to the logistics and local server ranges of a center |
| Gateway endpoints | Free private paths to S3 and DynamoDB |
| Interface endpoints | IoT Core data, S3 and the private API, when `enable_private_endpoints` is true |
| Virtual private gateway, customer gateway and VPN connection | Link to each center in `center_links`, when `enable_center_link` is true |

Three subnets hold an interface endpoint today, and four stay reserved so that a later component lands in its place with no renumbering.

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

  endpoint_security_group_ids = module.security.endpoint_security_group_ids

  vpc_name                 = local.vpc_name
  vpc_cidr                 = var.vpc_cidr
  subnets                  = local.subnets
  enable_private_endpoints = var.enable_private_endpoints
  enable_center_link       = var.enable_center_link
  center_links             = local.center_links
}
```

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment`, `additional_tags` | Governance | See below | Codes for tags and the extra tags of the module. `additional_tags` is optional |
| `vpc_name` | `string` | Yes | Final name of the VPC |
| `vpc_cidr` | `string` | Yes | Range of the VPC, a /16 that overlaps no center |
| `subnets` | `map(object)` | Yes | Name, range and availability zone of each subnet, keyed by purpose and zone |
| `endpoint_security_group_ids` | `map(string)` | Yes | Security group of each interface endpoint |
| `enable_private_endpoints` | `bool` | No | Creates the interface endpoints. Defaults to `false` |
| `enable_center_link` | `bool` | No | Creates the VPN links. Defaults to `false` |
| `center_links` | `map(object)` | No | Department code, public address of the center firewall and destination ranges of each link |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `subnet_ids` | IDs of the subnets, keyed like `subnets` |
| `route_table_ids` | IDs of the route tables |
| `vpn_connection_ids` | IDs of the VPN connections, keyed by department |
| `vpn_key_secret_arns` | ARNs of the secrets that hold the tunnel keys, keyed by department |

## Secrets

Terraform would keep the tunnel keys in its state as plain text if the code handled them. The connection therefore sets `preshared_key_storage = "SecretsManager"`, so AWS generates the keys and stores them in a secret, and the state holds only the ARN and a redacted value. The module declares no secret of its own, and the installer reads the keys from Secrets Manager to configure the center firewall.

## Cost

Only two items of this module bill by the hour, and each has a variable that turns it off for work sessions that do not need it.

| Item | Rate | Variable |
|---|---|---|
| One VPN connection | USD 0.05 per hour | `enable_center_link` |
| One interface endpoint in one zone | USD 0.01 per hour | `enable_private_endpoints` |

The VPC, the subnets, the routes and the gateway endpoints have no hourly charge.

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
