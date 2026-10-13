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
| `ipv4_base_cidr_block` | `string` | `null` | Base CIDR to auto-slice via `cidrsubnet()` for any `subnet_groups` entry that omits `cidr_block`. |
| `ipv4_subnet_newbits` | `number` | `null` | Extra bits carved per auto-sliced subnet (e.g. `8` to go from a `/16` base to `/24` subnets). |
| `subnet_groups` | `map(object)` | - | `cidr_block` (optional - auto-sliced from `ipv4_base_cidr_block` if omitted), `availability_zone`, `route_table_key`, `map_public_ip_on_launch`, `ipv6_enabled`, `assign_ipv6_address_on_creation`. |
| `route_tables` | `map(object)` | - | `routes` list: `cidr_block` or `ipv6_cidr_block` (never both) + one of `gateway_id`/`nat_gateway_id`/`network_interface_id`/`egress_only_gateway_id`. |
| `az_name_attribute` | `bool` | `false` | Prefix each subnet's name with a short AZ code, e.g. `acme-prod-euc1a-public-a`. |
| `az_code_overrides` | `map(string)` | `{}` | Per-AZ override/addition to the built-in region-code table, keyed by the full availability zone (e.g. `{"eu-central-1a" = "eu1"}`). |
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

Leave `ipv6_enabled` unset and it follows the VPC: on for every subnet
if `vpc_ipv6_cidr_block` is set, off otherwise. Set it explicitly per
subnet to override that. Setting `ipv6_enabled = true` without
`vpc_ipv6_cidr_block` fails plan with a clear error instead of a
cryptic one.

Each IPv6-enabled subnet gets a deterministic `/64` via
`cidrsubnet(vpc_ipv6_cidr_block, 8, <position in the sorted subnet_groups
keys>)` - same convention used by cloudposse's dynamic-subnets module.
Keep `subnet_groups` keys stable over time, or Terraform will reassign
every subnet's IPv6 CIDR. NAT Gateway never carries IPv6 traffic - route
private IPv6 egress through `egress_only_gateway_id` instead.

## Subnet CIDR allocation

Set `cidr_block` explicitly per `subnet_groups` entry for manual
control, or omit it and set `ipv4_base_cidr_block` +
`ipv4_subnet_newbits` once to auto-slice every subnet that omits
`cidr_block` via `cidrsubnet(ipv4_base_cidr_block, ipv4_subnet_newbits,
<stable index>)`. The index is each subnet's position in the sorted
`subnet_groups` keys - keep keys stable over time, or Terraform
reassigns every auto-sliced subnet's CIDR. Mixing explicit and
auto-sliced entries in the same `subnet_groups` map is fine; an
explicit `cidr_block` always wins for that entry.

## AZ naming

Set `az_name_attribute = true` to prefix each subnet's name with a
short AZ code, e.g. `eu-central-1a` -> `euc1a`, producing
`acme-prod-euc1a-public-a` instead of `acme-prod-public-a`. Codes come
from a hand-written table in `az_codes.tf` (current AWS regions, with
the `ap-south`/`ap-southeast` collision resolved). Override or add one
via `az_code_overrides`, keyed by the full availability zone:

```hcl
az_code_overrides = {
  "eu-central-1a" = "eu1"
}
```

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
