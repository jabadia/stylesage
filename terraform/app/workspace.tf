locals {
  ## Workspaces
  workspace_variables = {
    pro = {}
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
  buckets = {
    "${local.name_prefix}-statics" = {
      name                           = "${local.name_prefix}-statics"
      force_destroy                  = true
      acl                            = "private"
      versioning                     = { enable = false }
      block_public_acls              = false
      block_public_policy            = false
      ignore_public_acls             = false
      restrict_public_buckets        = false
      attach_elb_log_delivery_policy = false
      attach_policy                  = true
    }
    "${local.name_prefix}-cdn-logging" = {
      name                           = "${local.name_prefix}-cdn-logging"
      force_destroy                  = true
      acl                            = "private"
      versioning                     = { enable = false }
      block_public_acls              = true
      block_public_policy            = true
      ignore_public_acls             = true
      restrict_public_buckets        = true
      attach_elb_log_delivery_policy = false
      attach_policy                  = true
    }
    "${local.name_prefix}-alb-logging" = {
      name                           = "${local.name_prefix}-alb-logging"
      force_destroy                  = true
      acl                            = "private"
      versioning                     = { enable = false }
      block_public_acls              = true
      block_public_policy            = true
      ignore_public_acls             = true
      restrict_public_buckets        = true
      attach_elb_log_delivery_policy = true
      attach_policy                  = false
    }
  }
  //  cdns = {
  //    "${local.name_prefix}-statics" = {
  //      aliases                       = ["statics.${data.terraform_remote_state.base.outputs.zone_name}"]
  //      enabled                       = true
  //      retain_on_delete              = false
  //      wait_for_deployment           = true
  //      create_origin_access_identity = true
  //      origin_access_identities = {
  //        s3_bucket_statics = lookup(module.bucket, "${local.name_prefix}-statics").s3_bucket_id
  //      }
  //      logging_config = {
  //        bucket = lookup(module.bucket, "${local.name_prefix}-cdn-logging").s3_bucket_bucket_domain_name
  //      }
  //      origin = {
  //        s3_statics = {
  //          domain_name = lookup(module.bucket, "${local.name_prefix}-statics").s3_bucket_bucket_domain_name
  //          s3_origin_config = {
  //            origin_access_identity = "s3_bucket_statics"
  //          }
  //        }
  //      }
  //      default_cache_behavior = {
  //        target_origin_id       = "something"
  //        viewer_protocol_policy = "allow-all"
  //        allowed_methods        = ["GET", "HEAD", "OPTIONS"]
  //        cached_methods         = ["GET", "HEAD"]
  //        compress               = true
  //        query_string           = true
  //      }
  //      ordered_cache_behavior = [
  //        {
  //          path_pattern           = "/*"
  //          target_origin_id       = "s3_statics"
  //          viewer_protocol_policy = "redirect-to-https"
  //          allowed_methods        = ["GET", "HEAD", "OPTIONS"]
  //          cached_methods         = ["GET", "HEAD"]
  //          compress               = true
  //          query_string           = true
  //        }
  //      ]
  //      viewer_certificate = {
  //        acm_certificate_arn = data.terraform_remote_state.base.outputs.certificate_arn
  //        ssl_support_method  = "sni-only"
  //      }
  //    }
  //  }
  roles = {
    "${local.name_prefix}-ecs-role" = {
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
              Service = "ecs-tasks.amazonaws.com"
            }
          },
        ]
      })
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
      ]
      inline_policies = [
        {
          name = "${local.name_prefix}-s3-policy"
          policy = jsonencode({
            Version = "2012-10-17"
            Statement = [
              {
                Action = [
                  "s3:GetObject",
                  "s3:ListBucket",
                  "s3:GetBucketLocation",
                  "s3:GetObjectVersion",
                  "s3:PutObject",
                  "s3:PutObjectAcl",
                  "s3:GetLifecycleConfiguration",
                  "s3:PutLifecycleConfiguration",
                  "s3:DeleteObject"
                ]
                Effect = "Allow"
                Resource = [
                  lookup(module.bucket, "${local.name_prefix}-statics").s3_bucket_arn,
                  "${lookup(module.bucket, "${local.name_prefix}-statics").s3_bucket_arn}/*",
                ]
              },
            ]
          })
        }
      ]
    }
  }
  sg_alb = {
    "${local.name_prefix}-alb-sg" = {
      vpc_id              = data.terraform_remote_state.base.outputs.vpc_id
      ingress_cidr_blocks = ["0.0.0.0/0"]
      ingress_rules       = ["https-443-tcp", "http-80-tcp"]
      egress_rules        = ["all-all"]
    }
  }
  sg_ecs = {
    "${local.name_prefix}-ecs-sg" = {
      vpc_id = data.terraform_remote_state.base.outputs.vpc_id
      ingress_with_source_security_group_id = [
        {
          rule                     = "splunk-web-tcp" #This rule uses port 8000
          source_security_group_id = lookup(module.sg_alb, "${local.name_prefix}-alb-sg").security_group_id
        }
      ]
      egress_rules = [
      "all-all"]
    }
  }
  sg_db = {
    "${local.name_prefix}-postgresql-sg" = {
      vpc_id = data.terraform_remote_state.base.outputs.vpc_id
      ingress_with_source_security_group_id = [
        {
          rule                     = "postgresql-tcp"
          source_security_group_id = lookup(module.sg_ecs, "${local.name_prefix}-ecs-sg").security_group_id
        }
      ]
      egress_rules = ["all-all"]
    }
  }
  dbs = {
    "${local.name_prefix}-postgresql" = {
      engine                    = "postgres"
      engine_version            = "11.10"
      family                    = "postgres11"
      major_engine_version      = "11"
      instance_class            = "db.t3.micro"
      allocated_storage         = 5
      name                      = var.project
      username                  = var.project
      create_random_password    = true
      random_password_length    = 16
      port                      = 5432
      subnet_ids                = data.terraform_remote_state.base.outputs.database_subnets
      vpc_security_group_ids    = [lookup(module.sg_db, "${local.name_prefix}-postgresql-sg").security_group_id]
      maintenance_window        = "Mon:00:00-Mon:03:00"
      backup_window             = "03:00-06:00"
      backup_retention_period   = 0
      create_db_option_group    = false
      create_db_parameter_group = false
    }
  }
  albs = {
    "${local.name_prefix}-alb" = {
      type            = "application"
      internal        = false
      vpc_id          = data.terraform_remote_state.base.outputs.vpc_id
      subnets         = data.terraform_remote_state.base.outputs.public_subnets
      security_groups = [lookup(module.sg_alb, "${local.name_prefix}-alb-sg").security_group_id]
      http_listeners = [
        {
          port        = 80
          protocol    = "HTTP"
          action_type = "redirect"
          redirect = {
            port        = "443"
            protocol    = "HTTPS"
            status_code = "HTTP_301"
          }
        }
      ]
      https_listeners = [
        {
          port            = 443
          protocol        = "HTTPS"
          certificate_arn = data.terraform_remote_state.base.outputs.certificate_arn
        }
      ]
      target_groups = [
        {
          name_prefix      = "${local.environment}-"
          backend_protocol = "HTTP"
          backend_port     = 8000
          target_type      = "ip"
          health_check = {
            path    = "/admin"
            matcher = "200-399"
          }
          stickiness = {
            enabled = true
            type    = "lb_cookie"
          }
          deregistration_delay = 60
        }
      ]
      access_logs = {
        bucket = lookup(module.bucket, "${local.name_prefix}-alb-logging").s3_bucket_id
      }
    }
  }
  log_groups = {
    "/aws/ecs/${local.name_prefix}" = {
      retention_in_days = 7
    }
  }
  ecs_tasks = {
    "${local.name_prefix}" = {
      family                   = local.name_prefix
      cpu                      = 512
      memory                   = 1024
      requires_compatibilities = ["FARGATE"]
      network_mode             = "awsvpc"
      task_role_arn            = lookup(aws_iam_role.role, "${local.name_prefix}-ecs-role").arn
      execution_role_arn       = lookup(aws_iam_role.role, "${local.name_prefix}-ecs-role").arn
      container_definitions = jsonencode([
        {
          name             = local.name_prefix
          image            = var.image
          essential        = true
          workingDirectory = "/app"
          entryPoint       = ["/bin/sh", "-c", "python manage.py migrate && python manage.py createsu && python manage.py runserver 0.0.0.0:8000"]
          portMappings = [
            {
              containerPort = 8000
            }
          ],
          environment = [
            {
              name  = "DJANGO_SETTINGS_MODULE"
              value = "iotd.settings"
            },
            {
              name  = "RDS_DB_NAME"
              value = lookup(module.db, "${local.name_prefix}-postgresql").db_instance_name
            },
            {
              name  = "RDS_USERNAME"
              value = lookup(module.db, "${local.name_prefix}-postgresql").db_instance_username
            },
            {
              name  = "RDS_PASSWORD"
              value = lookup(module.db, "${local.name_prefix}-postgresql").db_instance_password
            },
            {
              name  = "RDS_HOSTNAME"
              value = lookup(module.db, "${local.name_prefix}-postgresql").db_instance_address
            },
            {
              name  = "RDS_PORT"
              value = tostring(lookup(module.db, "${local.name_prefix}-postgresql").db_instance_port)
            },
            {
              name  = "S3_BUCKET_NAME"
              value = lookup(module.bucket, "${local.name_prefix}-statics").s3_bucket_id
            }
          ],
          logConfiguration = {
            logDriver = "awslogs",
            options = {
              "awslogs-region"        = var.aws_region
              "awslogs-group"         = lookup(module.cloudwatch_log-group, "/aws/ecs/${local.name_prefix}").cloudwatch_log_group_name
              "awslogs-stream-prefix" = local.name_prefix
            }
          }
        }
      ])
    }
  }
  ecs_services = {
    "${local.name_prefix}" = {
      cluster                            = data.terraform_remote_state.base.outputs.ecs_cluster_id
      task_definition                    = lookup(aws_ecs_task_definition.ecs_task_definition, "${local.name_prefix}").arn
      desired_count                      = 1
      deployment_maximum_percent         = 200
      deployment_minimum_healthy_percent = 100
      load_balancer = {
        container_name   = local.name_prefix
        container_port   = 8000
        target_group_arn = lookup(module.alb, "${local.name_prefix}-alb").target_group_arns[0]
      }
      network_configuration = {
        subnets         = data.terraform_remote_state.base.outputs.private_subnets
        security_groups = [lookup(module.sg_ecs, "${local.name_prefix}-ecs-sg").security_group_id]
      }
      wait_for_steady_state = true
    }
  }
  records = {
    "oitd.${data.terraform_remote_state.base.outputs.zone_name}" = {
      zone_name = data.terraform_remote_state.base.outputs.zone_name
      records = [
        {
          name = "oitd"
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
