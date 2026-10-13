# terraform-aws-subnets

Terraform module provisioning subnets and route tables - decoupled from
each other and from NAT/VPC. Each route table brings its own target per
route (`gateway_id`, `nat_gateway_id`, `network_interface_id`, or
`egress_only_gateway_id` for IPv6), so this module has no opinion on how
traffic actually leaves the VPC. Pair with
[terraform-aws-vpc](https://github.com/rafalmasiarek/terraform-aws-vpc) for
the VPC, Internet Gateway, and (if `enable_ipv6 = true`) Egress-Only
Internet Gateway.

## Usage

```hcl
module "subnets" {
  source = "git::https://github.com/rafalmasiarek/terraform-aws-subnets.git?ref=v0.1.0"

  vpc_id = module.vpc.vpc_id

  route_tables = {
    public = {
      routes = [
        { cidr_block = "0.0.0.0/0", gateway_id = module.vpc.internet_gateway_id }
      ]
    }
  }

  subnet_groups = {
    public-a = {
      cidr_block              = "10.0.1.0/24"
      availability_zone       = "eu-central-1a"
      route_table_key         = "public"
      map_public_ip_on_launch = true
    }
  }

  tagger_context = module.tagger.context
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `vpc_id` | `string` | - | |
| `vpc_ipv6_cidr_block` | `string` | `null` | The VPC's own /56 (`module.vpc.ipv6_cidr_block`). Required if any `subnet_groups` entry sets `ipv6_enabled = true`. |
| `subnet_groups` | `map(object)` | - | `cidr_block`, `availability_zone`, `route_table_key`, `map_public_ip_on_launch`, `ipv6_enabled`, `assign_ipv6_address_on_creation`. |
| `route_tables` | `map(object)` | - | `routes` list: `cidr_block` or `ipv6_cidr_block` (never both) + one of `gateway_id`/`nat_gateway_id`/`network_interface_id`/`egress_only_gateway_id`. |
| `use_tagger` | `bool` | `true` | `false` applies `var.tags` as-is instead. |
| `tagger_context` | `any` | `null` | `module.tagger.context` from the root stack. |
| `tags` | `map(string)` | `{}` | Custom tags for the resource. |

## Outputs

| Name | Description |
|---|---|
| `subnet_ids` | Map keyed by `subnet_groups` key. |
| `route_table_ids` | Map keyed by `route_tables` key. |
| `subnet_ipv6_cidr_blocks` | Map keyed by `subnet_groups` key, only entries with `ipv6_enabled = true`. |

## IPv6

Each subnet with `ipv6_enabled = true` gets a deterministic `/64` via
`cidrsubnet(vpc_ipv6_cidr_block, 8, <position in the sorted subnet_groups
keys>)` - same convention used by cloudposse's dynamic-subnets module.
Keep `subnet_groups` keys stable over time, or Terraform will reassign
every subnet's IPv6 CIDR. NAT Gateway never carries IPv6 traffic - route
private IPv6 egress through `egress_only_gateway_id` instead.

## Tagging

Each subnet and each route table gets its own
[terraform-null-tagger](https://github.com/rafalmasiarek/terraform-null-tagger)
call (`for_each`), so every one gets its own `Name` tag while sharing the
same `tagger_context` and this module's own origin (detected via
[terraform-provider-tagger](https://github.com/rafalmasiarek/terraform-provider-tagger)).
Set `use_tagger = false` to bypass this and apply `var.tags` directly
instead.

Every subnet also carries `terraform-null-tagger`'s `network` category
(`vpc_id`, `availability_zone`) - e.g. `tagger:net:vpc-id`,
`tagger:net:availability-zone`. Route tables don't - a route table isn't
placed in a single AZ the way a subnet is.
