resource "aws_kms_key" "vault" {
    description                 = "Unseal Key for Vault"
    deletion_window_in_days     = var.deletion_window_in_days
    tags                        = local.tags             
}

