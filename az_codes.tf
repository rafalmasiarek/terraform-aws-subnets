# Static table of AWS region short codes (region only - the AZ letter
# itself, e.g. "a" in eu-central-1a, is appended separately and needs no
# table of its own). Hand-written, not computed, so new AWS regions need
# a line added here. The "ap-southeast-N" entries deliberately use 2
# letters ("apse") instead of 1 ("aps") - "south" is a prefix of
# "southeast", so a naive first-letter rule collides ap-south-N with
# ap-southeast-N. List current as of 2026-10; source: AWS's own public
# region list (api.regional-table.region-services.aws.a2z.com).
locals {
  az_code_table = {
    "af-south-1"     = "afs1"
    "ap-east-1"      = "ape1"
    "ap-east-2"      = "ape2"
    "ap-northeast-1" = "apn1"
    "ap-northeast-2" = "apn2"
    "ap-northeast-3" = "apn3"
    "ap-south-1"     = "aps1"
    "ap-south-2"     = "aps2"
    "ap-southeast-1" = "apse1"
    "ap-southeast-2" = "apse2"
    "ap-southeast-3" = "apse3"
    "ap-southeast-4" = "apse4"
    "ap-southeast-5" = "apse5"
    "ap-southeast-6" = "apse6"
    "ap-southeast-7" = "apse7"
    "ca-central-1"   = "cac1"
    "ca-west-1"      = "caw1"
    "eu-central-1"   = "euc1"
    "eu-central-2"   = "euc2"
    "eu-north-1"     = "eun1"
    "eu-south-1"     = "eus1"
    "eu-south-2"     = "eus2"
    "eu-west-1"      = "euw1"
    "eu-west-2"      = "euw2"
    "eu-west-3"      = "euw3"
    "eusc-de-east-1" = "euscde1"
    "il-central-1"   = "ilc1"
    "me-central-1"   = "mec1"
    "me-south-1"     = "mes1"
    "mx-central-1"   = "mxc1"
    "sa-east-1"      = "sae1"
    "us-east-1"      = "use1"
    "us-east-2"      = "use2"
    "us-gov-east-1"  = "usge1"
    "us-gov-west-1"  = "usgw1"
    "us-west-1"      = "usw1"
    "us-west-2"      = "usw2"
  }

  # Alternative to the hand-written table above: compute region codes
  # instead of maintaining them. Only covers regions actually used by
  # var.subnet_groups, so it never goes stale for new regions - but it
  # does NOT know about the ap-south/ap-southeast collision (or any
  # future one of the same shape), so switching to this requires
  # reviewing new regions yourself. To use: delete the az_code_table
  # map above and uncomment this one (same local name, so nothing else
  # in this file needs to change).
  #
  # az_code_table = {
  #   for region in distinct([
  #     for k, v in var.subnet_groups : substr(v.availability_zone, 0, length(v.availability_zone) - 1)
  #     if v.availability_zone != null
  #   ]) :
  #   region => join("", concat(
  #     [element(split("-", region), 0)],
  #     [for p in slice(split("-", region), 1, length(split("-", region)) - 1) : substr(p, 0, 1)],
  #     [element(split("-", region), length(split("-", region)) - 1)],
  #   ))
  # }

  # Final code per subnet: var.az_code_overrides overrides on an exact
  # availability_zone match, otherwise region code (from the table above)
  # + the AZ's own trailing letter. null for any subnet with no AZ set.
  az_code_by_subnet = {
    for k, v in var.subnet_groups : k => (
      v.availability_zone == null ? null :
      try(
        var.az_code_overrides[v.availability_zone],
        "${local.az_code_table[substr(v.availability_zone, 0, length(v.availability_zone) - 1)]}${substr(v.availability_zone, length(v.availability_zone) - 1, 1)}"
      )
    )
  }
}
