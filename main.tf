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
}

resource "aws_subnet" "this" {
  for_each = var.subnet_groups

  vpc_id                  = var.vpc_id
  cidr_block              = local.ipv4_cidr_by_key[each.key]
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  ipv6_cidr_block                 = each.value.ipv6_enabled ? cidrsubnet(var.vpc_ipv6_cidr_block, 8, local.subnet_index_by_key[each.key]) : null
  assign_ipv6_address_on_creation = each.value.ipv6_enabled ? each.value.assign_ipv6_address_on_creation : null

  tags = local.tagger_tags["subnet-${each.key}"]
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
}

resource "aws_route_table_association" "this" {
  for_each = var.subnet_groups

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.route_table_key].id
}
