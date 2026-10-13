variable "vpc_id" {
  description = "VPC to create subnets and route tables in."
  type        = string
}

variable "vpc_ipv6_cidr_block" {
  description = "The VPC's own /56 IPv6 CIDR (module.vpc.ipv6_cidr_block). Required if any subnet_groups entry sets ipv6_enabled = true - each such subnet gets a deterministic /64 via cidrsubnet(vpc_ipv6_cidr_block, 8, <position in the sorted subnet_groups keys>)."
  type        = string
  default     = null
}

variable "ipv4_base_cidr_block" {
  description = "Base IPv4 CIDR to auto-slice via cidrsubnet(), for any subnet_groups entry that omits its own cidr_block. Required if any entry omits cidr_block."
  type        = string
  default     = null
}

variable "ipv4_subnet_newbits" {
  description = "Additional bits carved from ipv4_base_cidr_block for each auto-sliced subnet (e.g. 8 to go from a /16 base to /24 subnets). Required if any subnet_groups entry omits cidr_block."
  type        = number
  default     = null
}

variable "subnet_groups" {
  description = "One aws_subnet per entry. route_table_key must match a key in var.route_tables. Omit cidr_block to auto-slice it from ipv4_base_cidr_block instead."
  type = map(object({
    cidr_block                      = optional(string)
    availability_zone               = optional(string)
    route_table_key                 = string
    map_public_ip_on_launch         = optional(bool, false)
    ipv6_enabled                    = optional(bool, false)
    assign_ipv6_address_on_creation = optional(bool, true)
  }))
}

variable "route_tables" {
  description = "One aws_route_table per entry. Bring your own target per route: gateway_id, nat_gateway_id, network_interface_id, or egress_only_gateway_id (IPv6 private egress - NAT Gateway does not carry IPv6 traffic). Set cidr_block for an IPv4 route or ipv6_cidr_block for an IPv6 route, never both."
  type = map(object({
    routes = optional(list(object({
      cidr_block             = optional(string)
      ipv6_cidr_block        = optional(string)
      gateway_id             = optional(string)
      nat_gateway_id         = optional(string)
      network_interface_id   = optional(string)
      egress_only_gateway_id = optional(string)
    })), [])
  }))
}

