#
# Standard wiring for terraform-null-tagger / terraform-provider-tagger.
# Identical in every module that uses it - copy verbatim, do not edit here.
#
# https://github.com/rafalmasiarek/terraform-null-tagger
# https://github.com/rafalmasiarek/terraform-provider-tagger
#
# Requires a local map named `taggable` (map(object)), defined elsewhere in
# this module - one entry per resource that needs tags. Each entry is
# { name = string, <any terraform-null-tagger service category> = ... } -
# only `name` is required, every category defaults to null if omitted.
#
# use_tagger = false bypasses all of this and uses var.tags directly. The
# tagger provider must still be declared in required_providers regardless -
# Terraform checks provider availability at init time independently of
# for_each = {}.
#

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
  description = "Custom tags for the resource(s)."
  type        = map(string)
  default     = {}
}

data "tagger_origin" "self" {
  count       = var.use_tagger ? 1 : 0
  module_path = path.module
}

module "tagger" {
  for_each = var.use_tagger ? local.taggable : {}
  source   = "rafalmasiarek/tagger/null"
  version  = ">= 0.1.0"
  context  = var.tagger_context
  name     = each.value.name

  origin_source  = data.tagger_origin.self[0].source
  origin_version = data.tagger_origin.self[0].version

  database          = try(each.value.database, null)
  compute           = try(each.value.compute, null)
  cache             = try(each.value.cache, null)
  load_balancer     = try(each.value.load_balancer, null)
  object_storage    = try(each.value.object_storage, null)
  block_storage     = try(each.value.block_storage, null)
  kubernetes        = try(each.value.kubernetes, null)
  serverless        = try(each.value.serverless, null)
  autoscaling_group = try(each.value.autoscaling_group, null)
  network           = try(each.value.network, null)
}

locals {
  # var.tags fills in keys tagger doesn't already produce - tagger's own
  # tags always win on conflict.
  tagger_tags = {
    for k in keys(local.taggable) :
    k => var.use_tagger ? merge(var.tags, module.tagger[k].tags) : var.tags
  }
}
