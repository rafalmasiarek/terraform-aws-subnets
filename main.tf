resource "aws_subnet" "this" {
  for_each = var.subnet_groups

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = local.subnet_tags[each.key]
}

resource "aws_route_table" "this" {
  for_each = var.route_tables

  vpc_id = var.vpc_id

  tags = local.route_table_tags[each.key]
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

  route_table_id         = aws_route_table.this[each.value.route_table_key].id
  destination_cidr_block = each.value.cidr_block
  gateway_id             = each.value.gateway_id
  nat_gateway_id         = each.value.nat_gateway_id
  network_interface_id   = each.value.network_interface_id
}

resource "aws_route_table_association" "this" {
  for_each = var.subnet_groups

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.route_table_key].id
}
