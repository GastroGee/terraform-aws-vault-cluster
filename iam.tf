resource "aws_iam_role" "vault_instance" {
    name                = "vault-instance"
    assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazoaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}
// Permissions that allows KMS to manage Sealing/Unsealing, Dynamodb to store data. 
// The Idea is to allow instances query configuration itself and run terraform remotely.
data "aws_iam_policy_document" "vault_policy" {
    statement {
        effect      = "Allow"

        actions     = [
            "ec2.DescribeTags",
        ]
        resources   = ["*"]
    }
    statement {
        effect      = "Allow"

        actions     = [
            "dynamodb:*",
        ]
        resources   = [aws_dnamodb_table.vault.arn]
    }
    statement {
        effect      = "Allow"
        sid         = "verifyawscreds"
        actions     = [
            "ec2.DescribeInstances",
            "iam.GetInstanceProfile",
            "iam.GetUser",
            "iam.GetRole",
        ]
        resources   = ["*"]
    }
    statement {
        effect      = "Allow"

        actions     = [
            "ssm:GetParameter",
            "ssm:GetParameterByPath",
            "ssm:PutParameter"
        ]
        resources   = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/*"]
    }
    statement {
        effect      = "Allow"
        sid         = "VaultKMSUnseal"
        actions     = [
            "kms:encrypt",
            "kms:decrypt",
            "kms:DescribeKey"
        ]
        resources   = ["*"]
    }
    // Depending on your usecase for Vault, you might need to assume role into other AWS accounts
    // Those accounts will need to explicitly allow this role that permission
    statement {
        effect      = "Allow"
        sid         = "assumerole"
        actions     = ["sts:assumerole"]
        resources   = ["*"]
    } 
    // Vault Needs to be able to get items from its dynamodb backend 
    statement {
        effect      = "Allow"
        sid         = "dynamodbackend"
        actions     = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem"
        ]
        resources   = [data.aws_dynamdb_table.lock_table.arn]
    }
    // In this setup, the vault instances are suppose to run a terraform run against the remote state 
    // to help with initial configuration.
    statement {
        effect      = "Allow"
        sid         = "terraforms3state"
        actions     = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject"
        ]
        resources   = ["arn:aws:s3:::${local.terraform_state_bucket}/*"]
    }    
 
}

// Vault Self-Trust SetUp

data "aws_iam_policy_document" "vault_trust_policy" {
    statement {
        actions     = ["sts:AssumeRole"]

        principals {
            type    = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }

        principals {
            type    = "AWS"
            identifiers = [aws_iam_role.vault_instance.arn]
        }
    }
}

// Create a role with the policy 
resource "aws_iam_role" "vault_trust_role" {
    name                = local.vault_trust_name
    assume_role_policy  = data.aws_iam_policy_document.vault_trust_policy.json
}

// Instance profile for the vault instances
resource "aws_iam_instance_profile" "vault_trust_instance" {
    name                = local.vault_trust_name
    role                = aws_iam_role.vault_trust_role.name
}

// End Self Setup 

data "aws_dynamo_table" "lock_table" {
    name                = local.dynamo_table
}

resource "aws_iam_policy" "vault_policy" {
    name                = "${local.vault_iam_prefix}-instance"
    policy              = data.aws_iam_policy_document.vault_policy.json
}

resource "aws_iam_policy_attachment" "vault_policy" {
    role                = aws_iam_role.vault_instance.id
    policy_arn          = aws_iam_policy.vault_policy.arn
}

resource "aws_iam_role_policy" "vault_policy" {
    name                = "${local.vault_iam_prefix}-instance"
    role                = aws_iam_role.vault_instance.id
    policy              = data.aws_iam_policy_document.vault_policy.json             
}

resource "aws_iam_instance_profile" "vault_secrets" {
    name                = "${local.vault_iam_prefix}-profile"
    role                = aws_iam_role.vault_instance.name
}
// Attaching AWS managed SSM Role 
resource "aws_iam_role_policy_attachment" "ssm" {
    role                = aws_iam_role.vault_instance.id
    policy_arn          = "arn:aws:iam:aws:policy/service-role/AmazonEC2RoleforSSM"
}
// Attaching AWS managed Cloudwatch
resource "aws_iam_role_policy_attachment" "cloudwatch" {
    role                = aws_iam_role.vault_instance.id
    policy_arn          = "arn:aws:iam:aws:policy/CloudwatchAgentServerPolicy"
}