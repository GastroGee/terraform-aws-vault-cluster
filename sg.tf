module "vault_instance_sg" {
    source          = "terraform-aws-modules/security-group/aws"
    version         = "4.7.0"

    use_name_prefix = false
    description     = "security group for vault instances"
    name            = "${local.name_prefix}-instance-secgrp"
    tags            = local.tags 
    vpc_id          = var.vpc_id

    egress_with_cidr_blocks = [
        {
            cidr_blocks     = "0.0.0.0/0"
            rule            = "https-443-tcp"
        },
        {
            cidr_blocks     = "0.0.0.0/0"
            rule            = "https-80-tcp"
        },   
        {
            cidr_blocks     = "0.0.0.0/0"
            description     = "dnsudp"
            from_port       = 53
            to_port         = 53
            protocol        = "udp"
        },
        {
            cidr_blocks     = "0.0.0.0/0"
            description     = "dnstcp"
            from_port       = 53
            to_port         = 53
            protocol        = "tcp"
        },    
    ]
    ingress_with_cidr_blocks = [
        {
            rule            = "ssh-tcp"
            cidr_blocks     = local.valid_cidr_blocks
        },
        {
            cidr_blocks     = local.valid_cidr_blocks
            from_port       = 8200
            to_port         = 8200
            protocol        = "tcp"
        },
    ]
    ingress_with_self       = [
        {
            from_port       = 8201
            to_port         = 8201
            protocol        = "tcp"
            description     = "vault ingress with self"
        }             
    ]
    egress_with_self       = [
        {
            from_port       = 8201
            to_port         = 8201
            protocol        = "tcp"
            description     = "vault egress with self"
        }             
    ]
    ingress_with_source_security_group_id = [
        {
            from_port       = 8200
            to_port         = 8200
            protocol        = "tcp"
            source_security_group_id     = module.vault_alb_sg.security_group_id                  
        }
    ]
}

module "vault_alb_sg" {
    source          = "terraform-aws-modules/security-group/aws"
    version         = "4.7.0"

    use_name_prefix = false
    description     = "security group for loadbalancers"
    name            = "${local.name_prefix}-alb-secgrp"
    tags            = local.tags 
    vpc_id          = var.vpc_id  

    ingress_with_cidr_blocks    = [
        {
            rule     = "https-443-tcp"
            cidr_blocks = local.valid_cidr_blocks
        }
    ]  
}