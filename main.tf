locals {
  subnet_taggable = {
    for k, v in var.subnet_groups : "subnet-${k}" => {
      name = k
      service = {
        network = {
          vpc_id            = var.vpc_id
          availability_zone = v.availability_zone
        }
      }
      attributes = var.az_name_attribute && v.availability_zone != null ? [local.az_code_by_subnet[k]] : []
    }
  }

  route_table_taggable = {
    for k, v in var.route_tables : "rt-${k}" => {
      name       = k
      service    = {}
      attributes = []
    }
  }

  taggable = merge(local.subnet_taggable, local.route_table_taggable)

  # Stable per-subnet index for cidrsubnet() - order must not change over
  # time or Terraform will reassign every subnet's CIDR. Shared by both
  # IPv4 auto-slicing and IPv6.
  subnet_keys_sorted  = sort(keys(var.subnet_groups))
  subnet_index_by_key = { for idx, k in local.subnet_keys_sorted : k => idx }

  # Explicit cidr_block always wins; only auto-slice when omitted.
  ipv4_cidr_by_key = {
    for k, v in var.subnet_groups :
    k => v.cidr_block != null ? v.cidr_block : cidrsubnet(var.ipv4_base_cidr_block, var.ipv4_subnet_newbits, local.subnet_index_by_key[k])
  }

  # Per-subnet opt-in: a subnet gets IPv6 only when its own flag is true.
  # The VPC-level CIDR is a prerequisite (validated below), not an implicit
  # switch that turns IPv6 on for every subnet.
  ipv6_enabled_by_key = {
    for k, v in var.subnet_groups :
    k => v.ipv6_enabled
  }

  any_subnet_wants_ipv6 = contains(values(var.subnet_groups[*].ipv6_enabled), true)
}

resource "aws_subnet" "this" {
  for_each = var.subnet_groups

  vpc_id                  = var.vpc_id
  cidr_block              = local.ipv4_cidr_by_key[each.key]
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  ipv6_cidr_block                 = local.ipv6_enabled_by_key[each.key] ? cidrsubnet(var.vpc_ipv6_cidr_block, 8, local.subnet_index_by_key[each.key]) : null
  assign_ipv6_address_on_creation = local.ipv6_enabled_by_key[each.key] ? each.value.assign_ipv6_address_on_creation : null

  tags = local.tagger_tags["subnet-${each.key}"]

  lifecycle {
    precondition {
      condition     = !local.ipv6_enabled_by_key[each.key] || var.vpc_ipv6_cidr_block != null
      error_message = "subnet_groups[\"${each.key}\"] has ipv6_enabled = true but vpc_ipv6_cidr_block was not provided."
    }
    precondition {
      condition     = each.value.cidr_block == null || can(cidrhost(each.value.cidr_block, 0))
      error_message = "subnet_groups[\"${each.key}\"].cidr_block \"${each.value.cidr_block}\" is not a valid CIDR."
    }
    precondition {
      condition     = each.value.cidr_block != null || (var.ipv4_base_cidr_block != null && var.ipv4_subnet_newbits != null)
      error_message = "subnet_groups[\"${each.key}\"] omits cidr_block but ipv4_base_cidr_block / ipv4_subnet_newbits are not set - cannot auto-slice."
    }
  }
}

resource "aws_route_table" "this" {
  for_each = var.route_tables

  vpc_id = var.vpc_id

  tags = local.tagger_tags["rt-${each.key}"]
}

locals {
  flattened_routes = merge([
    for rt_key, rt in var.route_tables : {
      for idx, route in rt.routes :
      "${rt_key}-${idx}" => merge(route, { route_table_key = rt_key })
    }
  ]...)
}

resource "aws_route" "this" {
  for_each = local.flattened_routes

  route_table_id = aws_route_table.this[each.value.route_table_key].id

  destination_cidr_block      = each.value.cidr_block
  destination_ipv6_cidr_block = each.value.ipv6_cidr_block

  gateway_id             = each.value.gateway_id
  nat_gateway_id         = each.value.nat_gateway_id
  network_interface_id   = each.value.network_interface_id
  egress_only_gateway_id = each.value.egress_only_gateway_id

  lifecycle {
    precondition {
      condition     = (each.value.cidr_block == null) != (each.value.ipv6_cidr_block == null)
      error_message = "route \"${each.key}\" in route table \"${each.value.route_table_key}\": set exactly one of cidr_block or ipv6_cidr_block, not both and not neither."
    }
    precondition {
      condition     = length([for t in [each.value.gateway_id, each.value.nat_gateway_id, each.value.network_interface_id, each.value.egress_only_gateway_id] : t if t != null]) == 1
      error_message = "route \"${each.key}\" in route table \"${each.value.route_table_key}\": set exactly one target (gateway_id, nat_gateway_id, network_interface_id, egress_only_gateway_id)."
    }
    precondition {
      condition     = contains(keys(var.route_tables), each.value.route_table_key)
      error_message = "route \"${each.key}\" references route_table_key \"${each.value.route_table_key}\" which does not exist in var.route_tables."
    }
  }
}

resource "aws_route_table_association" "this" {
  for_each = var.subnet_groups

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.route_table_key].id
}
