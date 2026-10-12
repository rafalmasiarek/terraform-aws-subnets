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

variable "use_tagger" {
  description = "Compute and apply standardized tags via terraform-null-tagger. When false, use var.tags as-is instead."
  type        = bool
  default     = true
}

variable "tagger_context" {
  description = "module.tagger.context from the root stack's base terraform-null-tagger call."
  type        = any
  default     = null
}

variable "tags" {
  description = "When use_tagger = true, fills in keys the tagger module doesn't already produce (tagger wins on conflict). Used as-is when use_tagger = false."
  type        = map(string)
  default     = {}
}
