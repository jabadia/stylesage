output "vpc_id" {
  value = lookup(module.vpc, "${local.name_prefix}-vpc").vpc_id
}

output "public_subnets" {
  value = lookup(module.vpc, "${local.name_prefix}-vpc").public_subnets
}

output "private_subnets" {
  value = lookup(module.vpc, "${local.name_prefix}-vpc").private_subnets
}

output "database_subnets" {
  value = lookup(module.vpc, "${local.name_prefix}-vpc").database_subnets
}

output "zone_id" {
  value = lookup(module.zones.route53_zone_zone_id, local.workspace["domain"])
}

output "zone_name" {
  value = lookup(module.zones.route53_zone_name, local.workspace["domain"])
}

output "certificate_arn" {
  value = lookup(module.acm, "*.${local.workspace["domain"]}").acm_certificate_arn
}

output "ecs_cluster_id" {
  value = lookup(module.ecs, local.name_prefix).ecs_cluster_id
}
