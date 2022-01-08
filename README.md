# Building Vault Cluster with a DynamoDB backend in AWS

This repo basically builds infrastructure to support Hashicorp's VAULT with a DynamoDB 
backend in AWS.

![Architecture](../images/architecture.png)

The repo is heavily dependent on bulding a special AMI with Vault binary installed and a couple helper scripts 

![AMI](https://github.com/gastrogee/packer-aws-vault)

## Build Custom AMI
Clone the AMI Repo 
```
git clone https://github.com/gastrogee/packer-aws-vault
```
Then export your access credentials 
```
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXX
```
Update the `variable` file with variables that are unique to your environment 
```
vpc_id="vpc-XXXXXXXXXXXXXXX"
ami_user="<aws account number>"
instance_type="m5.large"
subnet_id="subnet-XXXXXXXXXXXX"
```

Then build the custom AMI in your account 
```
packer build -var-file=variable.hcl server.hcl
```

## Deploy infrastructure with Created AMI 
Clone deployment repo 
```
git clone https://github.com/gastrogee/terraform-aws-vault-cluster
```
Update `variable.tf` with variable unique to your environment
or provide a variable file in `.tfvars`

Sample .tfvars
```
okta_org = "gastro"
okta_admin_groups = ["vault-prod-administrators", "vault-dev-administrators"]
pgp_recovery_keys   = ["jayz", "nas", "andre3000"]
vault_instance_count    = 3
instance_type   = "m5.2xlarge"
image_id    = "ami-XXXXXXXXXXXXXXXXXXXXX"
```

Then Run 
``` 
terraform init 
terraform plan 
terraform apply
```



