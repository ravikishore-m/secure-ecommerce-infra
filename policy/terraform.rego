package terraform.security

deny[msg] {
  input.resource_changes[_].change.after.tags.Environment == ""
  msg = "All resources must include an Environment tag"
}

deny[msg] {
  contains(lower(input.resource_changes[_].change.after.name), "public")
  not startswith(input.resource_changes[_].change.after.cidr_block, "10.")
  msg = "Public resources must use RFC1918 CIDRs"
}

