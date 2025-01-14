/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

################ SFE + Auction Setup ################

module "iam_roles" {
  source      = "../../services/iam_roles"
  environment = var.environment
  operator    = var.operator
}

module "iam_groups" {
  source      = "../../services/iam_groups"
  environment = var.environment
  operator    = var.operator
}

module "networking" {
  source   = "../../services/networking"
  operator = var.operator

  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
}

module "security_groups" {
  source      = "../../services/security_groups"
  environment = var.environment
  operator    = var.operator
  vpc_id      = module.networking.vpc_id
}

module "iam_group_policies" {
  source               = "../../services/iam_group_policies"
  operator             = var.operator
  environment          = var.environment
  ssh_users_group_name = module.iam_groups.ssh_users_group_name
  ssh_instance_arn     = module.ssh.ssh_instance_arn
}


module "backend_services" {
  source                          = "../../services/backend_services"
  region                          = var.region
  environment                     = var.environment
  operator                        = var.operator
  vpc_endpoint_route_table_ids    = module.networking.private_route_table_ids
  vpc_endpoint_sg_id              = module.security_groups.vpc_endpoint_security_group_id
  vpc_endpoint_subnet_ids         = module.networking.private_subnet_ids
  vpc_gateway_endpoint_services   = var.vpc_gateway_endpoint_services
  vpc_id                          = module.networking.vpc_id
  vpc_interface_endpoint_services = var.vpc_interface_endpoint_services
  server_instance_role_arn        = module.iam_roles.instance_role_arn
  ssh_instance_role_arn           = module.iam_roles.ssh_instance_role_arn
}

module "ssh" {
  source                  = "../../services/ssh"
  environment             = var.environment
  instance_sg_id          = module.security_groups.ssh_security_group_id
  operator                = var.operator
  ssh_instance_subnet_ids = module.networking.public_subnet_ids
  instance_profile_name   = module.iam_roles.ssh_instance_profile_name
  ssh_instance_type       = var.ssh_instance_type
}

module "security_group_rules" {
  source                            = "../../services/security_group_rules"
  region                            = var.region
  operator                          = var.operator
  environment                       = var.environment
  server_instance_port              = var.server_port
  vpc_id                            = module.networking.vpc_id
  elb_security_group_id             = module.security_groups.elb_security_group_id
  instances_security_group_id       = module.security_groups.instance_security_group_id
  ssh_security_group_id             = module.security_groups.ssh_security_group_id
  vpce_security_group_id            = module.security_groups.vpc_endpoint_security_group_id
  gateway_endpoints_prefix_list_ids = module.backend_services.gateway_endpoints_prefix_list_ids
  ssh_source_cidr_blocks            = var.ssh_source_cidr_blocks
}

module "iam_role_policies" {
  source                    = "../../services/iam_role_policies"
  operator                  = var.operator
  environment               = var.environment
  server_instance_role_name = module.iam_roles.instance_role_name
  ssh_instance_role_name    = module.iam_roles.ssh_instance_role_name
  autoscaling_group_arns    = [module.autoscaling_sfe.autoscaling_group_arn, module.autoscaling_auction.autoscaling_group_arn]
  # server_parameter_arns     = []
}

module "seller_dashboard" {
  source      = "../../services/dashboards/seller_dashboard"
  environment = var.environment
}

################ Seller FrontEnd operator Setup ################

####### Envoy-Specific Resources START #######
resource "aws_security_group_rule" "allow_elb_to_envoy_egress" {
  from_port                = var.envoy_port
  protocol                 = "TCP"
  security_group_id        = module.security_groups.elb_security_group_id
  to_port                  = var.envoy_port
  type                     = "egress"
  source_security_group_id = module.security_groups.instance_security_group_id
}

resource "aws_security_group_rule" "allow_elb_to_envoy_ingress" {
  from_port                = var.envoy_port
  protocol                 = "TCP"
  security_group_id        = module.security_groups.instance_security_group_id
  to_port                  = var.envoy_port
  type                     = "ingress"
  source_security_group_id = module.security_groups.elb_security_group_id
}


resource "aws_lb_target_group" "alb_http2_target_group" {
  name                 = "sfe-${var.environment}-${var.operator}-alb-http2-tg"
  port                 = var.envoy_port
  protocol             = "HTTP"
  protocol_version     = "HTTP2"
  vpc_id               = module.networking.vpc_id
  deregistration_delay = 30

  health_check {
    protocol            = "HTTP"
    port                = var.envoy_port
    path                = var.envoy_healthcheck_path
    interval            = var.healthcheck_interval_sec
    healthy_threshold   = var.healthcheck_healthy_threshold
    unhealthy_threshold = var.healthcheck_unhealthy_threshold
  }

  tags = {
    Name        = "sfe-${var.environment}-${var.operator}-alb-http2-tg"
    operator    = var.operator
    environment = var.environment
    service     = "sfe"
  }
}

resource "aws_lb_listener_rule" "public_alb_listener_http2_rule" {
  listener_arn = module.load_balancing_sfe.public_lb_listener_arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_http2_target_group.arn
  }
  condition {
    path_pattern {
      values = [
        "/v1/*"
      ]
    }
  }

  condition {
    http_request_method {
      values = ["POST"]
    }
  }
}

####### Envoy-Specific Resources STOP #######

module "load_balancing_sfe" {
  source                          = "../../services/load_balancing"
  environment                     = var.environment
  operator                        = var.operator
  service                         = "sfe"
  certificate_arn                 = var.certificate_arn
  elb_subnet_ids                  = module.networking.public_subnet_ids
  server_port                     = var.server_port
  vpc_id                          = module.networking.vpc_id
  elb_security_group_id           = module.security_groups.elb_security_group_id
  root_domain                     = var.root_domain
  root_domain_zone_id             = var.root_domain_zone_id
  healthcheck_healthy_threshold   = var.healthcheck_healthy_threshold
  healthcheck_interval_sec        = var.healthcheck_interval_sec
  healthcheck_unhealthy_threshold = var.healthcheck_unhealthy_threshold
}

module "autoscaling_sfe" {
  source                       = "../../services/autoscaling"
  environment                  = var.environment
  operator                     = var.operator
  enclave_debug_mode           = var.enclave_debug_mode
  service                      = "sfe"
  autoscaling_subnet_ids       = module.networking.private_subnet_ids
  instance_ami_id              = var.sfe_instance_ami_id
  instance_security_group_id   = module.security_groups.instance_security_group_id
  instance_type                = var.sfe_instance_type
  target_group_arns            = concat(module.load_balancing_sfe.target_group_arns, [aws_lb_target_group.alb_http2_target_group.arn])
  autoscaling_desired_capacity = var.sfe_autoscaling_desired_capacity
  autoscaling_max_size         = var.sfe_autoscaling_max_size
  autoscaling_min_size         = var.sfe_autoscaling_min_size
  instance_profile_arn         = module.iam_roles.instance_profile_arn
  enclave_cpu_count            = var.sfe_enclave_cpu_count
  enclave_memory_mib           = var.sfe_enclave_memory_mib
}


################ Auction operator Setup ################


module "load_balancing_auction" {
  source                          = "../../services/load_balancing"
  environment                     = var.environment
  operator                        = var.operator
  service                         = "auction"
  certificate_arn                 = var.certificate_arn
  elb_subnet_ids                  = module.networking.public_subnet_ids
  server_port                     = var.server_port
  vpc_id                          = module.networking.vpc_id
  elb_security_group_id           = module.security_groups.elb_security_group_id
  root_domain                     = var.root_domain
  root_domain_zone_id             = var.root_domain_zone_id
  healthcheck_healthy_threshold   = var.healthcheck_healthy_threshold
  healthcheck_interval_sec        = var.healthcheck_interval_sec
  healthcheck_unhealthy_threshold = var.healthcheck_unhealthy_threshold
  # Recommended not to change. Ensures internal VPC load balancers for traffic over private network.
  internal = true
}

module "autoscaling_auction" {
  source                       = "../../services/autoscaling"
  environment                  = var.environment
  operator                     = var.operator
  enclave_debug_mode           = var.enclave_debug_mode
  service                      = "auction"
  autoscaling_subnet_ids       = module.networking.private_subnet_ids
  instance_ami_id              = var.auction_instance_ami_id
  instance_security_group_id   = module.security_groups.instance_security_group_id
  instance_type                = var.auction_instance_type
  target_group_arns            = module.load_balancing_auction.target_group_arns
  autoscaling_desired_capacity = var.auction_autoscaling_desired_capacity
  autoscaling_max_size         = var.auction_autoscaling_max_size
  autoscaling_min_size         = var.auction_autoscaling_min_size
  instance_profile_arn         = module.iam_roles.instance_profile_arn
  enclave_cpu_count            = var.auction_enclave_cpu_count
  enclave_memory_mib           = var.auction_enclave_memory_mib
}


################ Parameter Setup ################

resource "aws_ssm_parameter" "runtime_flags" {
  for_each = var.runtime_flags

  name      = "${var.operator}-${var.environment}-${each.key}"
  type      = "String"
  value     = each.value
  tier      = "Intelligent-Tiering"
  overwrite = true
}
