variable "bucket_name" {
    default     = ""
}

variable "alb_name" {}

variable "nlb_name" {}

variable "nlb_listener_port" {
    default     = 443
}

variable "name_prefix" {}

variable "lambda_function_name" {
    default     = ""
}

variable "lambda_path" {
    default     = ""
}

variable "runtime_config_bucket" {}

variable "vpc_id" {}
