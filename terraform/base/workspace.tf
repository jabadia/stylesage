locals {
  ## Workspaces
  workspace_variables = {
    pre = {
      vpc = {
        cidr = "10.0.0.0/16"
      }
      domain = "pre.cesararroba.com"
    }
    pro = {
      vpc = {
        cidr = "10.10.0.0/16"
      }
      domain = "cesararroba.com"
    }
  }

  ## Common workspace.tf variables
  environment = terraform.workspace
  name_prefix = "${local.environment}-${var.project}"
  workspace   = merge(local.workspace_variables[terraform.workspace])
  tags = merge(
    var.aws_tags,
    tomap({
      "project" = var.project }
    ),
    tomap({
      "workspace" = terraform.workspace
    })
  )

  ## Resources variables
  vpcs = {
    "${local.name_prefix}-vpc" = {
      cidr                 = local.workspace["vpc"]["cidr"]
      azs                  = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
      enable_nat_gateway   = true
      single_nat_gateway   = true
      public_subnets       = [cidrsubnet(local.workspace["vpc"]["cidr"], 8, 11), cidrsubnet(local.workspace["vpc"]["cidr"], 8, 12)]
      private_subnets      = [cidrsubnet(local.workspace["vpc"]["cidr"], 8, 21), cidrsubnet(local.workspace["vpc"]["cidr"], 8, 22)]
      database_subnets     = [cidrsubnet(local.workspace["vpc"]["cidr"], 8, 31), cidrsubnet(local.workspace["vpc"]["cidr"], 8, 32)]
      enable_dns_hostnames = true
      enable_dns_support   = true
    }
  }
  zones = {
    "${local.workspace["domain"]}" = {
      tags = {
        Name = local.workspace["domain"]
      }
    }
  }
  certificates = {
    "*.${local.workspace["domain"]}" = {
      zone_id                   = lookup(module.zones.route53_zone_zone_id, local.workspace["domain"])
      subject_alternative_names = []
      wait_for_validation       = true
      tags                      = local.tags
    }
  }
  ecs_clusters = {
    "${local.name_prefix}" = {
      capacity_providers = ["FARGATE"]
      default_capacity_provider_strategy = [
        {
          capacity_provider = "FARGATE"
          weight            = 1
        }
      ]
    }
  }
  records = {
    "iotd.${data.terraform_remote_state.base.outputs.zone_name}" = {
      zone_name = data.terraform_remote_state.base.outputs.zone_name
      records = [
        {
          name = "iotd"
          type = "CNAME"
          ttl  = 300
          records = [
            lookup(module.alb, "${local.name_prefix}-alb").lb_dns_name
          ]
        },
      ]
    }
  }
}
