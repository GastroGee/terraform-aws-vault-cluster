variable "key_name" {
    default = ""
}

variable "volume_size" {
    default = 30
}

variable "image_id" {
    default = "packer-vault"
}

variable "instance_type" {
    default = "t2.small"
}

variable "asg_min_size" {
    default = 0
}

variable "asg_max_size" {
    default = 5
}

variable "vault_instance_count" {
    default = 2
}

variable "wait_for_capacity_timeout" {
    default = "10m"
}

variable "vpc_id" {
}

variable "deregistration_delay" {
    default = 20
}

variable "terraform_state_bucket" {
}

variable "zone" {  
    default = "gastrollc.com" 
}

variable "zone_name" {  
    default = ""  
}

variable "deletion_window_in_days" {
    default = 10
}

variable "pgp_operator_keys" {
    description = "list of public PGP keys then will be used as recovery keys in Vault"
    type    = list(string)
}

variable "lambda_path" {
    default = "/lambda.zip"
}

variable "offload_tls" {
    default = false
}
