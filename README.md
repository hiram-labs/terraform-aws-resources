# AWS Fargate Terraform Playbook

This repository contains a Terraform playbook for provisioning a production-grade AWS Fargate infrastructure. It includes all the necessary services and resources to create a scalable, secure, and efficient cloud environment.

## Prerequisites

Before getting started, ensure you have the following installed:

- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://aws.amazon.com/cli/)
- [Python 3](https://www.python.org/downloads/)
- Docker (for working with AWS ECR)

## Setting Up a Python Virtual Environment

Clone the repository and set up a virtual environment:

```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo
   python3 -m venv .venv
   source .venv/bin/activate
```

## Installing Terraform

1. Download Terraform from the [official website](https://www.terraform.io/downloads.html).
2. Unzip the downloaded file and move the binary to a directory in your `$PATH`:

```bash
   mv terraform /usr/local/bin/
   terraform -version
```

## Installing and Configuring AWS CLI

If you don't have AWS CLI installed, use the following command:

```bash
   pip install awscli
   aws --version
```

If AWS CLI is already configured with a `~/.aws` directory, you can skip configuration. Otherwise, run:

```bash
   aws configure
```

## Configuring an AWS Container Registry (ECR)

Authenticate Docker with AWS ECR:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.<region>.amazonaws.com
```

Tag and push an image to ECR (ensure the repository exists in ECR beforehand):

```bash
docker tag <local-image:version> <aws-account-id>.dkr.ecr.<region>.amazonaws.com/<ecr-repo-name>/local-image:version
docker push <aws-account-id>.dkr.ecr.<region>.amazonaws.com/<ecr-repo-name>/local-image:version
```

## Managing Terraform State

### Configuring Remote State Backend (Recommended for Teams)

For team collaboration and state protection, enable remote state storage in S3 with DynamoDB locking:

**1. Set your configuration variables:**
```bash
PROJECT_NAME="playground"  # From var.project_name
ENVIRONMENT="dev"          # From var.environment
AWS_REGION="eu-west-2"     # From var.aws_region
```

**2. Create the S3 bucket for state storage:**
```bash
BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-terraform-state"

aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}
```

**3. Enable versioning on the bucket:**
```bash
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled
```

**4. Create DynamoDB table for state locking:**
```bash
aws dynamodb create-table \
  --table-name ${PROJECT_NAME}-${ENVIRONMENT}-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${AWS_REGION}
```

**5. Enable the backend configuration:**

Uncomment the backend block in `backend.tf`, then initialize with CLI flags:

```bash
terraform init \
  -backend-config="bucket=${PROJECT_NAME}-${ENVIRONMENT}-terraform-state" \
  -backend-config="dynamodb_table=${PROJECT_NAME}-${ENVIRONMENT}-terraform-lock" \
  -backend-config="region=${AWS_REGION}" \
  -migrate-state
```

**6. Verify the backend configuration:**
```bash
terraform init
```

> **Note:** Once enabled, all team members must use the same backend configuration. The state file will be stored remotely and locked during operations to prevent conflicts.

### Importing Existing AWS Resources into Terraform

To import an existing AWS resource into Terraform state:

```bash
terraform import module.<module_name>.aws_route53_zone.primary Z1234567890ABC
```

### Removing an Entry from Terraform State

If needed, remove a resource from the Terraform state:

```bash
terraform state rm 'module.r53'
```

## Working with Multiple AWS Profiles

If your `~/.aws/credentials` file contains multiple accounts (profiles), you can specify a profile using an environment variable:

```bash
AWS_PROFILE=your-profile-name terraform plan
```

Alternatively, specify the profile in the Terraform AWS provider configuration:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "your-profile-name"
}
```

## Manually Setting AWS Credentials in Terraform

Although not recommended for security reasons, you can provide credentials directly in the provider block:

```hcl
provider "aws" {
  region     = "us-east-1"
  access_key = "your-access-key"
  secret_key = "your-secret-key"
}
```

## Conclusion

This playbook provides a streamlined approach to deploying AWS Fargate infrastructure using Terraform. Ensure best practices by managing credentials securely and version-controlling your Terraform configurations.
