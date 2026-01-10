########################################################################
# Local Values Configuration                                           #
#                                                                      #
# Defines local values used throughout the Terraform configuration,    #
# including common resource tags for consistent tagging strategy       #
# across all AWS resources.                                            #
########################################################################

locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "terraform-aws-resources"
    Owner       = var.owner
  }

  # Compute name prefix for resources
  name_prefix = "${var.project_name}-${var.environment}"
}
