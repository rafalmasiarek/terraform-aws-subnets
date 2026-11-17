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
