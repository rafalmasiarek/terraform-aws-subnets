output "subnet_ids" {
  value = { for k, s in aws_subnet.this : k => s.id }
}

output "public_subnet_ids" {
  description = "Subnet IDs where role = \"public\"."
  value       = [for k, s in aws_subnet.this : s.id if var.subnet_groups[k].role == "public"]
}

output "private_subnet_ids" {
  description = "Subnet IDs where role = \"private\" (NAT-routed)."
  value       = [for k, s in aws_subnet.this : s.id if var.subnet_groups[k].role == "private"]
}

output "isolated_subnet_ids" {
  description = "Subnet IDs where role = \"isolated\" (no internet egress)."
  value       = [for k, s in aws_subnet.this : s.id if var.subnet_groups[k].role == "isolated"]
}

output "endpoint_subnet_ids" {
  description = "Subnet IDs where role = \"endpoint\" (dedicated to VPC endpoints)."
  value       = [for k, s in aws_subnet.this : s.id if var.subnet_groups[k].role == "endpoint"]
}

output "route_table_ids" {
  value = { for k, rt in aws_route_table.this : k => rt.id }
}

output "subnet_ipv6_cidr_blocks" {
  value = { for k, s in aws_subnet.this : k => s.ipv6_cidr_block if s.ipv6_cidr_block != null }
}

output "nat_topology" {
  description = "Declared NAT topology: per-az or shared. Informational - this module does not create NAT gateways."
  value       = var.nat_topology
}
