output "subnet_ids" {
  value = { for k, s in aws_subnet.this : k => s.id }
}

output "route_table_ids" {
  value = { for k, rt in aws_route_table.this : k => rt.id }
}

output "subnet_ipv6_cidr_blocks" {
  value = { for k, s in aws_subnet.this : k => s.ipv6_cidr_block if s.ipv6_cidr_block != null }
}
