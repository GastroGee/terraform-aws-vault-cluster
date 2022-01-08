data "aws_lb" "alb" {
  name = var.alb_name
}

data "aws_lb" "nlb" {
  name = var.nlb_name
}

data "aws_s3_bucket" "config_bucket" {
  bucket = var.runtime_config_bucket
}
data "aws_lb_listener" "nlb_default_listener" {
  load_balancer_arn = data.aws_lb.nlb.arn
  port = var.nlb_listener_port
}