########################################################################
# Remote State Backend Configuration                                   #
#                                                                      #
# Backend configuration cannot use variables, so values must be        #
# provided via CLI flags during terraform init.                        #
#                                                                      #
# Usage:                                                               #
#   terraform init \                                                   #
#     -backend-config="bucket=myproject-dev-terraform-state" \         #
#     -backend-config="dynamodb_table=myproject-dev-terraform-lock" \  #
#     -backend-config="region=eu-west-2" \                             #
#     -migrate-state                                                   #
#                                                                      #
# Use your actual project_name, environment, and aws_region values.    #
########################################################################

## Uncomment to enable remote state backend
terraform {
  backend "s3" {
    # Values provided via -backend-config flags during init
    key     = "terraform.tfstate"
    encrypt = true
  }
}
