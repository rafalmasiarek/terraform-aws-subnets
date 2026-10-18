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

output "subnet_egress_targets" {
  description = "Per-subnet egress target ID (NAT Gateway, IGW, EIGW, or null for isolated). Derived from route_tables."
  value = {
    for k, v in var.subnet_groups :
    k => local.egress_target_by_subnet[k]
  }
}

output "topology_mermaid" {
  description = "Mermaid flowchart of the network topology. Paste into a README.md fenced code block with language 'mermaid' to render."
  value       = local.topology_mermaid
}
