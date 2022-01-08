resource "aws_dynamodb_table" "vault" {
    name            = "${local.name_prefix}-data"
    billing_mode    = "PAY_PER_REQUEST"
    hash_key        = "Path"
    range_key       = "Key"

    attribute {
        name        = "Path"
        type        = "S"
    }

    attribute {
        name        = "Key"
        type        = "S"
    }

    point_in_time_recovery {
        enabled     = true
    }

    tags            = local.tags

}

resource "aws_ssm_parameter" "vault_dynamo_region" {
    name            = "/vault_dynamo_region"
    value           = data.aws_region.current.name
    type            = "String"
    overwrite       = true
}

resource "aws_ssm_parameter" "vault_dynamo_table" {
    name            = "/vault_dynamo_table"
    value           = aws_dynamodb_table.vault.name
    type            = "String"
    overwrite       = true
}
