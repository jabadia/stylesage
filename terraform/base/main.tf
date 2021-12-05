# Stylesage Base stack

## VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  for_each             = local.vpcs
  name                 = each.key
  cidr                 = local.vpcs[each.key].cidr
  enable_nat_gateway   = local.vpcs[each.key].enable_nat_gateway
  single_nat_gateway   = local.vpcs[each.key].single_nat_gateway
  azs                  = local.vpcs[each.key].azs
  public_subnets       = local.vpcs[each.key].public_subnets
  private_subnets      = local.vpcs[each.key].private_subnets
  database_subnets     = local.vpcs[each.key].database_subnets
  enable_dns_hostnames = local.vpcs[each.key].enable_dns_hostnames
  enable_dns_support   = local.vpcs[each.key].enable_dns_support
  tags                 = local.tags
}

## Route53
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "2.4.0"

  zones = local.zones
  tags  = local.tags
}

## ACM
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "3.2.1"

  for_each                  = local.certificates
  domain_name               = each.key
  zone_id                   = local.certificates[each.key].zone_id
  subject_alternative_names = local.certificates[each.key].subject_alternative_names
  wait_for_validation       = local.certificates[each.key].wait_for_validation
  tags                      = local.tags
}

## ECS
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "3.4.1"

  for_each           = local.ecs_clusters
  name               = each.key
  capacity_providers = local.ecs_clusters[each.key].capacity_providers
  default_capacity_provider_strategy = local.ecs_clusters[each.key].default_capacity_provider_strategy
  tags               = local.tags
}
