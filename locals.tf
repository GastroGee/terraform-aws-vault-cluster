locals {
    tags                        = [
        {
            key                 = "Name"
            value               = local.name_prefix
            propagate_at_launch = true 
        },
        {
            key                 = "Owner"
            value               = local.owner
            propagate_at_launch = true 
        },
        {
            key                 = "Service"
            value               = "Vault"
            propagate_at_launch = true 
        }        
    ]
    name_prefix                 = "${terraform.workspace}-vault"
    terraform_state_bucket      = var.terraform_state-bucket
    dynamo_table                = "${local.terraform_state_bucket}-lock-table"
    vault_iam_prefix            = "${local.name_prefix}-secret-${data.aws_region.current.name}"
    vault_iam_suffix            = "${data.aws_region.current.name}-${terraform.workspace}"
    bucket_prefix               = "${local.name_prefix}-lb"
    subnets                     = var.subnets
    public_subnets              = toset(var.public_subnets)
    private_subnets             = toset(var.private_subnets)
    cert_name                   = var.cert_name
    create_dns_entry            = var.zone_name != "" ? var.zone_name : var.zone
    zone                        = var.zone_name != "" ? var.zone_name : var.zone
    log_group_name              = "/aws/"
    valid_cidr_blocks           = var.valid_cidr_blocks
    runtime_config_bucket       = var.runtime_config_bucket
    vault_trust_name            = "vault-self"
}