// Vault Unseal keys can be encyrpted PGP Keys. This resource uploads all operator PGP keys to S3
// Vault init scripts can then decrypt unseal keys with asc keys in S3 on launch 
resource "aws_s3_bucket_object" "operator" {
    count                       = length(var.pgp_operator_keys)
    bucket                      = var.runtime_config_bucket
    key                         = "/operatorkeys/${element(var.pgp_operator_keys, count.index)}.asc"
    source                      = "${path.module}/operatorkeys/${element(var.pgp_operator_keys, count.index)}.asc"
}
// Writing the recovery keys to parameter store which could be consumed an init script during launch
resource "aws_ssm_parameter" "pgp_unseal_key_files" {
    name                        = "/pgp_recovery_key_files"
    value                       = join(",", aws_s3_bucket_object.key.*.key)
    type                        = "String"
    tier                        = "Advanced"
}