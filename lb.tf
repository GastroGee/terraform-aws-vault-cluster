// First We create a Network Loadbalancer with Elastics IPs for Vault. In some vault usecases;
// e.g. TLS cert Auth Method, TLS is not offloaded to the loadbalancer hence the need of a Network 
// loadbalancer.
resource "aws_lb" "vault" {
    name_prefix             = "vault"
    internal                = false
    load_balancer_type      = "network"
    enable_cross_zone_load_balancing    = true 
    tags                    = local.tags

    access_logs {
        bucket          = aws_s3_bucket.lb_logs.bucket 
        prefix          = "${local.bucket_prefix}-network"
        enabled         = true
    }
    dynamic "subnet_mapping" {
        for_each    = local.subnets
        content {
            subnet_id       = subnet_mapping.value 
            allocation_id   = aws_eip.lb_ip[subnet_mapping.value].id
        }
    }
    lifecyle {
        create_before_destroy  = true
    }
}

// Depending on Vault Use Case, we could also use an Application Loadbalancer. In this Usecase, TLS can be offloaded
// to the application loadbalancer 

resource "aws_lb" "vault_application" {
    count               = var.offload_tls ? 1:0
    name_prefix         = "vault"
    internal            = true 
    load_balancer_type  = "application"
    tags                = local.tags
    security_groups     = [ module.vault_alb_sg.security_group_id ]

    access_logs {
        bucket          = aws_s3_bucket.lb_logs.bucket
        prefix          = "${local.bucket_prefix}-application"
        enabled         = true
    }
    subnets             = local.subnets
    lifecycle {
        create_before_destroy   = true
    }
}

data "aws_acm_certificate" "vault" {
    count               = var.offload_tls ? 1 : 0
    domain              = local.cert_name
    statuses            = ["ISSUED"]
    most_recent         = true 
}

data "aws_route53_zone" "vault" {
    count               = local.create_dns_entry
    name                = local.zone    
}

resource "aws_route53_record" "vault" {
    count               = local.create_dns_entry
    zone_id             = data.aws_route53_zone.vault[count.index].zone_id
    name                = local.dns_name 
    type                = "CNAME"
    ttl                 = 30
    records             = [aws_lb.vault.dns_name]

    lifecycle {
        ignore_changes  = [name]
    }
}

data "aws_elb_service_account" "main" {
}

data "aws_iam_policy_document" "lb_logs" {
    statement {
        sid     = "AWSLogDeliveryWrite"

        actions = [
            "s3:putObject",
        ]
        resources = formatlist("arn:aws:s3:::${aws_s3_bucket.lb_logs.bucket}/%s/AWSLogs/*",
        ["${local.bucket_prefix}-application", "${local.bucket_prefix}-network"])

        principal {
            type        = "Service"
            identifiers = ["delivery.logs.amazonaws.com"]
        }
        principal {
            type        = "AWS"
            identifiers = [data.aws_elb_service_account.main.arn]
        }
    }
    statement {
        sid     = "AWSLogDeliveryCheck"

        principals {
            type        = "Service"
            identifiers = ["delivery.logs.amazonaws.com"]
        }
        actions = [
            "s3:GetBucketAcl",
        ]
        resources = [
            "arn:aws:s3:::${aws_s3_bucket.lb_logs.bucket}",
        ]
    }
}
// Single entrypoint for all connections. Will forward to target groups for the ALB or the instance depending on 
// TLS termination 
resource "aws_lb_listener" "vault_nlb" {
    load_balancer_arn           = aws_lb.vault.arn
    port                        = "443"
    protocol                    = "TCP"

    default_action  {
        type                    = "forward"
        target_group_arn        = var.offload_tls ? aws_lb_target.vault_nlb_forward[0].arn : aws_lb_target_group.vault_tcp_8200[0].arn
    }  
}
// Temination TLS on loadbalancer mean we need HTTPS listeners 
resource "aws_lb_listener" "vault_application" {
    count                       = var.offload_tls ? 1: 0
    load_balancer_arn           = aws_lb_vault.application[count.index].arn
    port                        = "443"
    protocol                    = "HTTPS"

    ssl_policy                  = "ELBSecuritypolicy-2016-08"
    certificate_arn             = data.aws_acm_certificate.vault[count.index].arn

    default_action {
        type                    = "forward"
        target_group_arn        = aws_lb_target.vault_http_8200[count.index].arn 
    }
}

// Create S3 bucket for loadbalancer logs 
resource "aws_s3_bucket" "lb_logs" {
    bucket                      = "${local.name_prefix}-lb"
    acl                         = "private"

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm  = "AE256"
            }
        }
    }
    tags                        = local.tags
}
// Attach policy above to logs bucket 
resource "aws_s3_bucket_policy" "lb_logs" {
    bucket                      = aws_s3_bucket.lb_logs.bucket
    policy                      = data.aws_iam_policy_document.lb_logs.json
}
