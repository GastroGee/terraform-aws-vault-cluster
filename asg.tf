resource "aws_launch_configuration" "vault" {
    name_prefix             = "vault"
    security_groups         = [module.vault_instance_sg.security_group_id]

    root_block_device {
        volume_size         = var.volume_size
    }
    key_name                = var.key_name
    image_id                = var.image_id
    instance_type           = var.instance_type

    iam_instance_profile    = aws_iam_instance_profile.vault_instance.name

    lifecycle {
        create_before_destroy   = true
    }
}

resource "aws_autoscaling_group" "vault" {
    name                    = aws_launch_configuration.vault.name
    vpc_zone_identifier     = local.private_subnets
    min_size                = var.asg_min_size 
    max_size                = var.asg_max_size
    desired_capacity        = var.vault_instance_count

    wait_for_elb_capacity   = var.vault_instance_count

    wait_for_capacity_timeout   = var.wait_for_capacity_timeout

    timeouts {
        delete              = "15m"
    }

    launch_configuration    = aws_launch_configuration.vault.name 
    lifecyle {
        create_before_destroy   = true
    }

    initial_lifecycle_hook {
        name                = "operator-shutdown"
        default_result      = "ABANDON"
        heartbeat_timeout   = 900
        lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"

        notification_target_arn     = aws_sns_topic.scale_in.arn 
        role_arn                    = aws_iam_role.scale_in.arn
    }
    termination_policies        = ["OldestLaunchConfiguration", "OldestInstance"]

    tags                    = local.tags

    // Vault Seal/Unseal is managed by AWS KMS which is created here and written to parameter store
    depends_on = [
        aws_ssm_parameter.vault_kms_key,
        aws_ssm_parameter.vault_lb
    ]
    target_group_arns   = [var.offload_tls ? aws_lb_target_group.vault_http_8200[0].arn : aws_lb_target_group.vault_http_8200[0].arn]
}

// All Instances get added to the target group 
resource "aws_autoscaling_attachment" "asg_attachment_vault" {
    autoscaling_group_name          = aws_autoscaling_group.vault.name
    alb_target_group_arn            = var.offload_tls ? aws_lb_target_group.vault_http_8200[0].arn : aws_lb_target_group.vault_http_8200[0].arn
    lifecycle {
        create_before_destroy       = true
    }
}


// Introducing a target group that helps with nlb to alb forwarding
resource "aws_lb_target_group" "vault_nlb_forward" {
    count                           = var.offload_tls ? 1 : 0
    name                            = "${local.name_prefix}-443"
    port                            = 443
    protocol                        = "TCP"
    vpc_id                          = var.vpc_id

    target_type                     = "ip"

    health_check {
        protocol                    = "HTTPS"
        port                        = 443
    }
    stickiness {
        enabled                     = false 
        type                        = "source_ip"
    }
}

// If we are terminating SSL on the loadbalancer; then each instance will register here 
resource "aws_lb_target_group" "vault_http_8200" {
    count                           = var.offload_tls ? 1 : 0
    name                            = "${local.name_prefix}-http-8200"
    port                            = 8200
    protocol                        = "HTTP"
    vpc_id                          = local.vpc_id 

    target_type                     = "instance"

    deregistration_delay            = var.deregistration_delay

    health_check {
        protocol                    = "HTTP"
        path                        = "/v1/sys/health"
        // vault operates on only one active node, while other nodes in the cluster are passive
        // healthchecks on active node return 200, while passive return 429
        matcher                     = "200,429"
        port                        = 8200
    }

}

resource "aws_lb_target_group" "vault_tcp_8200" {
    count                           = var.offload_tls ? 0 : 1
    name                            = "${local.name_prefix}-tcp-8200"
    port                            = 8200
    protocol                        = "TCP"
    vpc_id                          = local.vpc_id 

    target_type                     = "instance"

    deregistration_delay            = var.deregistration_delay

    health_check {
        protocol                    = "HTTP"
        port                        = 8200
    }

}
