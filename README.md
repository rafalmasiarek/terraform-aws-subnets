# terraform-aws-subnets
## About

Terraform module provisioning subnets and route tables - decoupled from
each other and from NAT/VPC. Each route table brings its own target per
route (`gateway_id`, `nat_gateway_id`, `network_interface_id`, or
`egress_only_gateway_id` for IPv6), so this module has no opinion on how
traffic actually leaves the VPC. Pair with
[terraform-aws-vpc](https://github.com/rafalmasiarek/terraform-aws-vpc) for
the VPC, Internet Gateway, and (if `enable_ipv6 = true`) Egress-Only
Internet Gateway.



## License
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

```text
The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files, to deal in the Software
without restriction.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

Source: https://opensource.org/licenses/MIT
```
See [LICENSE](LICENSE) for full details.
## Authors

- Rafał Masiarek | [website](https://masiarek.pl) | [email](mailto:rafal@masiarek.pl) | [github](https://github.com/rafalmasiarek)


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

## IPv6 allocation

Set `ipv6_enabled = true` per `subnet_groups` entry to opt that subnet
into IPv6. By default, its `/64` is auto-sliced from
`vpc_ipv6_cidr_block` via `cidrsubnet(vpc_ipv6_cidr_block, 8, <stable
index>)`, same stable index as IPv4 auto-slicing. Set `ipv6_cidr_block`
explicitly on that entry to supply an externally computed `/64`
instead (e.g. from an IPAM system, or any other external source) - it
always wins over the auto-slice calculation, and the module doesn't
care where it came from. Mixing auto-sliced and explicit IPv6
allocations in the same `subnet_groups` map is fine, independently per
subnet. `ipv6_cidr_block` is ignored (and rejected by a precondition)
unless `ipv6_enabled = true` on the same entry.

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


<!-- BEGIN_TF_DOCS -->


### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_tagger"></a> [tagger](#requirement\_tagger) | >= 0.1.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tagger"></a> [tagger](#module\_tagger) | rafalmasiarek/tagger/null | >= 0.5.0 |

### Resources

| Name | Type |
|------|------|
| [aws_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| tagger_origin.self | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_az_code_overrides"></a> [az\_code\_overrides](#input\_az\_code\_overrides) | Per-AZ override for az\_code\_table, e.g. { "eu-central-1a" = "eu1" }. Only used when az\_name\_attribute = true. | `map(string)` | `{}` | no |
| <a name="input_az_name_attribute"></a> [az\_name\_attribute](#input\_az\_name\_attribute) | Add a short AZ code (e.g. euc1a) as a name\_prefix attribute to every subnet - the code comes before the subnet's own name, e.g. acme-prod-euc1a-public-a. Default false - no change to existing naming. | `bool` | `false` | no |
| <a name="input_ipv4_base_cidr_block"></a> [ipv4\_base\_cidr\_block](#input\_ipv4\_base\_cidr\_block) | Base IPv4 CIDR to auto-slice via cidrsubnet(), for any subnet\_groups entry that omits its own cidr\_block. Required if any entry omits cidr\_block. | `string` | `null` | no |
| <a name="input_ipv4_subnet_newbits"></a> [ipv4\_subnet\_newbits](#input\_ipv4\_subnet\_newbits) | Additional bits carved from ipv4\_base\_cidr\_block for each auto-sliced subnet (e.g. 8 to go from a /16 base to /24 subnets). Required if any subnet\_groups entry omits cidr\_block. | `number` | `null` | no |
| <a name="input_route_tables"></a> [route\_tables](#input\_route\_tables) | One aws\_route\_table per entry. Bring your own target per route: gateway\_id, nat\_gateway\_id, network\_interface\_id, or egress\_only\_gateway\_id (IPv6 private egress - NAT Gateway does not carry IPv6 traffic). Set cidr\_block for an IPv4 route or ipv6\_cidr\_block for an IPv6 route, never both. | <pre>map(object({<br/>    routes = optional(list(object({<br/>      cidr_block             = optional(string)<br/>      ipv6_cidr_block        = optional(string)<br/>      gateway_id             = optional(string)<br/>      nat_gateway_id         = optional(string)<br/>      network_interface_id   = optional(string)<br/>      egress_only_gateway_id = optional(string)<br/>    })), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_subnet_groups"></a> [subnet\_groups](#input\_subnet\_groups) | One aws\_subnet per entry. route\_table\_key must match a key in var.route\_tables. Omit cidr\_block to auto-slice it from ipv4\_base\_cidr\_block instead. Omit ipv6\_cidr\_block (with ipv6\_enabled = true) to auto-slice a /64 from vpc\_ipv6\_cidr\_block instead - set it explicitly to use an externally computed /64 (e.g. from another IPAM source) instead of the module's own cidrsubnet() calculation. role selects the routing profile: public, private, isolated, or endpoint. | <pre>map(object({<br/>    cidr_block                      = optional(string)<br/>    ipv6_cidr_block                 = optional(string)<br/>    availability_zone               = optional(string)<br/>    route_table_key                 = string<br/>    map_public_ip_on_launch         = optional(bool, false)<br/>    ipv6_enabled                    = optional(bool, false)<br/>    assign_ipv6_address_on_creation = optional(bool, true)<br/>    role                            = optional(string, "private")<br/>  }))</pre> | n/a | yes |
| <a name="input_tagger_additional_services"></a> [tagger\_additional\_services](#input\_tagger\_additional\_services) | Extra terraform-null-tagger `service` data per taggable resource, keyed by the same key as local.taggable (e.g. "subnet-public-a"). Merged on top of what this module computes automatically - lets a caller tag something this module doesn't know about, without waiting for a new module release. | `any` | `{}` | no |
| <a name="input_tagger_context"></a> [tagger\_context](#input\_tagger\_context) | module.tagger.context from the root stack's base terraform-null-tagger call. | `any` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Custom tags for the resource(s). | `map(string)` | `{}` | no |
| <a name="input_use_tagger"></a> [use\_tagger](#input\_use\_tagger) | Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead. | `bool` | `true` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC to create subnets and route tables in. | `string` | n/a | yes |
| <a name="input_vpc_ipv6_cidr_block"></a> [vpc\_ipv6\_cidr\_block](#input\_vpc\_ipv6\_cidr\_block) | The VPC's own /56 IPv6 CIDR (module.vpc.ipv6\_cidr\_block). Required if any subnet\_groups entry sets ipv6\_enabled = true and omits its own ipv6\_cidr\_block - such a subnet gets a deterministic /64 via cidrsubnet(vpc\_ipv6\_cidr\_block, 8, <position in the sorted subnet\_groups keys>). | `string` | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_endpoint_subnet_ids"></a> [endpoint\_subnet\_ids](#output\_endpoint\_subnet\_ids) | Subnet IDs where role = "endpoint" (dedicated to VPC endpoints). |
| <a name="output_isolated_subnet_ids"></a> [isolated\_subnet\_ids](#output\_isolated\_subnet\_ids) | Subnet IDs where role = "isolated" (no internet egress). |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Subnet IDs where role = "private" (NAT-routed). |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Subnet IDs where role = "public". |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | n/a |
| <a name="output_subnet_allocations"></a> [subnet\_allocations](#output\_subnet\_allocations) | Effective per-subnet allocation details (actual values in use, whether auto-sliced or externally supplied), keyed the same as subnet\_groups. |
| <a name="output_subnet_egress_targets"></a> [subnet\_egress\_targets](#output\_subnet\_egress\_targets) | Per-subnet egress target ID (NAT Gateway, IGW, EIGW, or null for isolated). Derived from route\_tables. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | n/a |
| <a name="output_subnet_ipv6_cidr_blocks"></a> [subnet\_ipv6\_cidr\_blocks](#output\_subnet\_ipv6\_cidr\_blocks) | n/a |
| <a name="output_topology_mermaid"></a> [topology\_mermaid](#output\_topology\_mermaid) | Mermaid flowchart of the network topology. Paste into a README.md fenced code block with language 'mermaid' to render. |
<!-- END_TF_DOCS -->


<!-- references -->

[repo_link]: https://github.com/rafalmasiarek/terraform-aws-subnets
