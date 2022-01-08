// Writing a couple of configuration items in parameter store which could then be consumed by 
// ansible as a runtime configuration.
resource "aws_ssm_parameter" "offload_tls" {
    name            = "/offload_tls"
    value           = var.offload_tls
    type            = "String"
    overwrite       = true
}

resource "aws_ssm_parameter" "vault_lb" {
    name            = "/load_balancer_address"
    value           = local.create_dns_entry ? "https://${join(",", aws-route53_record.vault.*.fqdn)}:443" : "https://vault.${var.zone_name}:443"
    type            = "String"
    overwrite       = true
}

resource "aws_ssm_parameter" "vault_zone" {
    name            = "/zone"
    value           = local.create_dns_entry ? var.zone_name : " "
    type            = "String"
    overwrite       = true
}

resource "aws_ssm_parameter" "vault_kms_key" {
    name            = "/seal_key"
    value           = aws_kms_key.vault.id
    type            = "String"
    overwrite       = true
}

resource "aws_ssm_parameter" "vault_okta_admin_groups" {
    name            = "/okta_admin_groups"
    value           = join(",", formatlist("\"%s\"", var.okta_admin_groups))
    type            = "String"
}

resource "aws_ssm_parameter" "vault_okta_org" {
    name            = "/okta_org"
    value           = var.okta_org
    type            = "String"
}

resource "aws_ssm_parameter" "vault_okta_url" {
    name            = "/okta_base_url"
    value           = var.okta_base_url
    type            = "String"
}

resource "aws_ssm_parameter" "runtime_bucket" {
    name            = "/runtime_config_bucket"
    value           = aws_s3_bucket.config.bucket_domain_name
    type            = "String"
}

output "vault_addr" {
    value           = local.create_dns_entry ? "https://${join(",", aws-route53_record.vault.*.fqdn)}:443" : "https://vault.${var.zone_name}:443"
}

output "elastic_ips" {
    value = [
        for eip in aws_eip.lb_ip : eip.public_ip
    ]
}

output "lb_arn" {
    value           = aws_lb.vault.arn
}

