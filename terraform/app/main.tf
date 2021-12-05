# Stylesage IOTD stack

## S3
module "bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.11.1"

  for_each                       = local.buckets
  bucket                         = each.key
  force_destroy                  = local.buckets[each.key].force_destroy
  acl                            = local.buckets[each.key].acl
  versioning                     = local.buckets[each.key].versioning
  block_public_acls              = local.buckets[each.key].block_public_acls
  block_public_policy            = local.buckets[each.key].block_public_policy
  ignore_public_acls             = local.buckets[each.key].ignore_public_acls
  restrict_public_buckets        = local.buckets[each.key].restrict_public_buckets
  attach_elb_log_delivery_policy = local.buckets[each.key].attach_elb_log_delivery_policy
  attach_policy                  = local.buckets[each.key].attach_policy
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly"
        Principal = "*"
        Effect    = "Deny"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${each.key}",
          "arn:aws:s3:::${each.key}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = local.tags
}

## IAM
resource "aws_iam_role" "role" {
  for_each            = local.roles
  name                = each.key
  assume_role_policy  = local.roles[each.key].assume_role_policy
  managed_policy_arns = local.roles[each.key].managed_policy_arns
  tags                = local.tags

  dynamic "inline_policy" {
    for_each = local.roles[each.key].inline_policies
    content {
      name   = inline_policy.value["name"]
      policy = inline_policy.value["policy"]
    }
  }
}

## SG
module "sg_alb" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  for_each            = local.sg_alb
  name                = each.key
  vpc_id              = local.sg_alb[each.key].vpc_id
  ingress_cidr_blocks = local.sg_alb[each.key].ingress_cidr_blocks
  ingress_rules       = local.sg_alb[each.key].ingress_rules
  egress_rules        = local.sg_alb[each.key].egress_rules
  tags                = local.tags
}

module "sg_ecs" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  for_each                              = local.sg_ecs
  name                                  = each.key
  vpc_id                                = local.sg_ecs[each.key].vpc_id
  ingress_with_source_security_group_id = local.sg_ecs[each.key].ingress_with_source_security_group_id
  egress_rules                          = local.sg_ecs[each.key].egress_rules
  tags                                  = local.tags
}

module "sg_db" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  for_each                              = local.sg_db
  name                                  = each.key
  vpc_id                                = local.sg_db[each.key].vpc_id
  ingress_with_source_security_group_id = local.sg_db[each.key].ingress_with_source_security_group_id
  egress_rules                          = local.sg_db[each.key].egress_rules
  tags                                  = local.tags
}

## RDS
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "3.4.1"

  for_each                  = local.dbs
  identifier                = each.key
  engine                    = local.dbs[each.key].engine
  engine_version            = local.dbs[each.key].engine_version
  family                    = local.dbs[each.key].family
  major_engine_version      = local.dbs[each.key].major_engine_version
  instance_class            = local.dbs[each.key].instance_class
  allocated_storage         = local.dbs[each.key].allocated_storage
  name                      = local.dbs[each.key].name
  username                  = local.dbs[each.key].username
  create_random_password    = local.dbs[each.key].create_random_password
  random_password_length    = local.dbs[each.key].random_password_length
  port                      = local.dbs[each.key].port
  subnet_ids                = local.dbs[each.key].subnet_ids
  vpc_security_group_ids    = local.dbs[each.key].vpc_security_group_ids
  maintenance_window        = local.dbs[each.key].maintenance_window
  backup_window             = local.dbs[each.key].backup_window
  backup_retention_period   = local.dbs[each.key].backup_retention_period
  create_db_option_group    = local.dbs[each.key].create_db_option_group
  create_db_parameter_group = local.dbs[each.key].create_db_parameter_group
  tags                      = local.tags
}

## Load Balancers
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.6.1"

  for_each           = local.albs
  name               = each.key
  load_balancer_type = local.albs[each.key].type
  internal           = local.albs[each.key].internal
  vpc_id             = local.albs[each.key].vpc_id
  subnets            = local.albs[each.key].subnets
  security_groups    = local.albs[each.key].security_groups
  http_tcp_listeners = local.albs[each.key].http_listeners
  https_listeners    = local.albs[each.key].https_listeners
  target_groups      = local.albs[each.key].target_groups
  access_logs        = local.albs[each.key].access_logs
  tags               = local.tags
}

## CloudWatch Log Group
module "cloudwatch_log-group" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/log-group"
  version = "2.1.0"

  for_each          = local.log_groups
  name              = each.key
  retention_in_days = local.log_groups[each.key].retention_in_days
  tags              = local.tags
}

## ECS TaskDefinition
resource "aws_ecs_task_definition" "ecs_task_definition" {
  for_each                 = local.ecs_tasks
  family                   = local.ecs_tasks[each.key].family
  cpu                      = local.ecs_tasks[each.key].cpu
  memory                   = local.ecs_tasks[each.key].memory
  requires_compatibilities = local.ecs_tasks[each.key].requires_compatibilities
  network_mode             = local.ecs_tasks[each.key].network_mode
  task_role_arn            = local.ecs_tasks[each.key].task_role_arn
  execution_role_arn       = local.ecs_tasks[each.key].execution_role_arn
  container_definitions    = local.ecs_tasks[each.key].container_definitions
  tags                     = local.tags
}

## ECS Service
resource "aws_ecs_service" "ecs_service" {
  for_each                           = local.ecs_services
  name                               = each.key
  cluster                            = local.ecs_services[each.key].cluster
  task_definition                    = local.ecs_services[each.key].task_definition
  desired_count                      = local.ecs_services[each.key].desired_count
  deployment_maximum_percent         = local.ecs_services[each.key].deployment_maximum_percent
  deployment_minimum_healthy_percent = local.ecs_services[each.key].deployment_minimum_healthy_percent

  load_balancer {
    container_name   = local.ecs_services[each.key].load_balancer.container_name
    container_port   = local.ecs_services[each.key].load_balancer.container_port
    target_group_arn = local.ecs_services[each.key].load_balancer.target_group_arn
  }

  network_configuration {
    subnets         = local.ecs_services[each.key].network_configuration.subnets
    security_groups = local.ecs_services[each.key].network_configuration.security_groups
  }

  wait_for_steady_state = local.ecs_services[each.key].wait_for_steady_state

  lifecycle {
    ignore_changes = [capacity_provider_strategy]
  }

  tags = local.tags
}

## Route53 Record
module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "2.4.0"

  for_each  = local.records
  zone_name = local.records[each.key].zone_name
  records   = local.records[each.key].records
}
