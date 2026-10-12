# terraform-aws-subnets

Terraform module provisioning subnets and route tables - decoupled from
each other and from NAT/VPC. Each route table brings its own target per
route (`gateway_id`, `nat_gateway_id`, or `network_interface_id`), so this
module has no opinion on how traffic actually leaves the VPC. Pair with
[terraform-aws-vpc](https://github.com/rafalmasiarek/terraform-aws-vpc) for
the VPC and Internet Gateway.

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
| `subnet_groups` | `map(object)` | - | `cidr_block`, `availability_zone`, `route_table_key`, `map_public_ip_on_launch`. |
| `route_tables` | `map(object)` | - | `routes` list: `cidr_block` + one of `gateway_id`/`nat_gateway_id`/`network_interface_id`. |
| `use_tagger` | `bool` | `true` | `false` applies `var.tags` as-is instead. |
| `tagger_context` | `any` | `null` | `module.tagger.context` from the root stack. |
| `tags` | `map(string)` | `{}` | Custom tags for the resource. |

## Outputs

| Name | Description |
|---|---|
| `subnet_ids` | Map keyed by `subnet_groups` key. |
| `route_table_ids` | Map keyed by `route_tables` key. |

## Tagging

Each subnet and each route table gets its own
[terraform-null-tagger](https://github.com/rafalmasiarek/terraform-null-tagger)
call (`for_each`), so every one gets its own `Name` tag while sharing the
same `tagger_context` and this module's own origin (detected via
[terraform-provider-tagger](https://github.com/rafalmasiarek/terraform-provider-tagger)).
Set `use_tagger = false` to bypass this and apply `var.tags` directly
instead.
