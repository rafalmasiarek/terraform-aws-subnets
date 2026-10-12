output "subnet_ids" {
  value = { for k, s in aws_subnet.this : k => s.id }
}

output "route_table_ids" {
  value = { for k, rt in aws_route_table.this : k => rt.id }
}
