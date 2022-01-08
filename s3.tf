// Create S3 bucket for Runtime Configuration
resource "aws_s3_bucket" "config" {
    bucket                      = "${local.name_prefix}-runtime"
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

data "aws_iam_policy_document" "config" {
    statement {
        sid     = "AWSConfigReadWrite"

        actions = [
            "s3:putObject",
            "s3:GetObject"
        ]
        resources = [ 
            "arn:aws:s3:::${aws_s3_bucket.config.bucket}/*"
        ]

        principal {
            type        = "AWS"
            identifiers = [data.aws_elb_service_account.main.arn]
        }
    }
    statement {
        sid     = "AWSConfigCheck"

        actions = [
            "s3:GetBucketAcl",
        ]
        resources = [
            "arn:aws:s3:::${aws_s3_bucket.config.bucket}",
        ]
    }
}


// Attach policy above to logs bucket 
resource "aws_s3_bucket_policy" "config" {
    bucket                      = aws_s3_bucket.config.bucket
    policy                      = data.aws_iam_policy_document.config.json
}