# AWS Fargate Terraform Playbook

This repository contains a Terraform playbook designed to provision a production-grade AWS Fargate infrastructure and other resources. It includes all the recommended services and resources required for a scalable, secure, and efficient cloud environment.

## Set Up a Python Virtual Environment

```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo
   python3 -m venv .venv
   source .venv/bin/activate
```

## Install Terraform

- Go to [Terraform Downloads](https://www.terraform.io/downloads.html) and download the version suitable for your operating system.

- Unzip the downloaded file and move the `terraform` binary to a directory in your `$PATH`. For example:

```bash
   mv terraform /usr/local/bin/
   terraform -version
```

## Install and Configure AWS CLI

No need to configure aws if you already have a `~/.aws` directory configured

```bash
   pip install awscli
   aws --version
   aws configure
```

## Configuring an AWS container registry

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.<region>.amazonaws.com

# tag an image and push to ecr (you have to create an ecr repo before hand)
docker tag <local-image:version> <aws-account-id>.dkr.ecr.<region>.amazonaws.com/<ecr-repo-name>/local-image:version
docker push <aws-account-id>.dkr.ecr.<region>.amazonaws.com/<ecr-repo-name>/local-image:version
```
