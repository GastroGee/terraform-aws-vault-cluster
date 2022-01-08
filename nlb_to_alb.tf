// https://aws.amazon.com/blogs/networking-and-content-delivery/using-aws-lambda-to-enable-static-ip-addresses-for-application-load-balancers/
// Using AWS Lambda to enable static IP addresses for Application Load Balancers
// you can register ALB as a target of NLB to forward traffic from NLB to ALB without needing to actively manage ALB IP address changes through Lambda.



module "nlb_alb" {
    count       = var.offload_tls ? 1 : 0
    source      = "./nlb_alb/"
    nlb_name    = aws_lb.vault.name
    alb_name    = aws_lb.vault_application[count.index].name
    tags        = local.tags
    vpc_id      = var.vpc_id
    runtime_config_bucket   = aws_s3_bucket.config.id
    name_prefix   = "vault"
}