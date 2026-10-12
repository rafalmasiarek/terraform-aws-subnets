variable "vpc_id" {
  description = "VPC to create subnets and route tables in."
  type        = string
}

variable "subnet_groups" {
  description = "One aws_subnet per entry. route_table_key must match a key in var.route_tables."
  type = map(object({
    cidr_block              = string
    availability_zone       = optional(string)
    route_table_key         = string
    map_public_ip_on_launch = optional(bool, false)
  }))
}

variable "route_tables" {
  description = "One aws_route_table per entry. Bring your own target per route: gateway_id, nat_gateway_id, or network_interface_id."
  type = map(object({
    routes = optional(list(object({
      cidr_block           = string
      gateway_id           = optional(string)
      nat_gateway_id       = optional(string)
      network_interface_id = optional(string)
    })), [])
  }))
}

