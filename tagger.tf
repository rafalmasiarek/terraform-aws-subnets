# terraform-null-tagger / terraform-provider-tagger wiring.
# One tagger call per subnet/route table (for_each), so each gets its own
# Name tag while sharing context/origin. use_tagger = false falls back to
# var.tags; provider is still required regardless (init validates it
# independently of for_each = {}).

data "tagger_origin" "self" {
  count       = var.use_tagger ? 1 : 0
  module_path = path.module
}

module "tagger_subnet" {
  for_each = var.use_tagger ? var.subnet_groups : {}
  source   = "git::https://github.com/rafalmasiarek/terraform-null-tagger.git?ref=v0.1.0"
  context  = var.tagger_context
  name     = each.key

  origin_source  = data.tagger_origin.self[0].source
  origin_version = data.tagger_origin.self[0].version
}

module "tagger_route_table" {
  for_each = var.use_tagger ? var.route_tables : {}
  source   = "git::https://github.com/rafalmasiarek/terraform-null-tagger.git?ref=v0.1.0"
  context  = var.tagger_context
  name     = each.key

  origin_source  = data.tagger_origin.self[0].source
  origin_version = data.tagger_origin.self[0].version
}

locals {
  # var.tags fills in keys tagger doesn't already produce - tagger's own
  # tags always win on conflict.
  subnet_tags = {
    for k in keys(var.subnet_groups) :
    k => var.use_tagger ? merge(var.tags, module.tagger_subnet[k].tags) : var.tags
  }

  route_table_tags = {
    for k in keys(var.route_tables) :
    k => var.use_tagger ? merge(var.tags, module.tagger_route_table[k].tags) : var.tags
  }
}
