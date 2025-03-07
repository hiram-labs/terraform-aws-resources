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
