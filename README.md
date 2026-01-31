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

### Authenticating with ECR

Authenticate Docker with AWS ECR:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.<region>.amazonaws.com
```

### Pushing Images to Private ECR

Tag and push an image to ECR (ensure the repository exists in ECR beforehand):

```bash
docker tag <local-image:version> <aws-account-id>.dkr.ecr.<region>.amazonaws.com/<ecr-repo-name>/local-image:version
docker push <aws-account-id>.dkr.ecr.<region>.amazonaws.com/<ecr-repo-name>/local-image:version
```

### Migrating Public Images to Private ECR

For private subnet tasks (when `use_nat_gateway = false`), you need to copy public container images to your private ECR:

```bash
# Get your ECR repository URL and extract region from it
ECR_REPO=$(terraform output -json ecr_repository_urls | jq -r '.app')
AWS_REGION=$(echo $ECR_REPO | cut -d'.' -f4)

# Authenticate with ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}

# Pull the public image
docker pull public.ecr.aws/nginx/nginx:1.27-bookworm

# Tag it for your private ECR
docker tag public.ecr.aws/nginx/nginx:1.27-bookworm ${ECR_REPO}:nginx-1.27-bookworm

# Push to your private ECR
docker push ${ECR_REPO}:nginx-1.27-bookworm
```

Then update your task definition JSON files to reference the private ECR image:
```json
"image": "<aws-account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:nginx-1.27-bookworm"
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

---

## Production Deployment Guide

### Pre-Deployment Checklist

Before deploying to production, ensure you have:

- [ ] **Domain Name**: Registered and ready for DNS configuration
- [ ] **SSL Certificate**: Will be automatically created via ACM with DNS validation
- [ ] **AWS Account**: Production account with appropriate IAM permissions
- [ ] **Backend State**: S3 bucket and DynamoDB table created for state management
- [ ] **Alert Email**: Valid email address for CloudWatch alarm notifications
- [ ] **SSH Keys**: Generated SSH key pair for EC2 access
- [ ] **Docker Images**: Container images pushed to ECR
- [ ] **Review Variables**: All variables in `terraform.tfvars` configured appropriately
- [ ] **Cost Review**: Reviewed infrastructure costs (databases, NAT Gateway, etc.)
- [ ] **Backup Plan**: Understood RDS/DocumentDB snapshot policies

> **Important Note on NAT Gateway**: When `use_nat_gateway = false`, private subnet tasks can **only** pull container images from your private AWS ECR repository. VPC endpoints are configured for ECR API, ECR Docker, and S3, enabling private ECR access without internet connectivity. However, public registries (Docker Hub, AWS Public ECR, etc.) will be inaccessible. If you need to use public container images in private tasks, either:
> - Enable NAT Gateway (`use_nat_gateway = true`), or
> - Copy public images to your private ECR first, or
> - Deploy tasks in public subnets instead

### Environment-Specific Configurations

#### Development Environment
```hcl
environment         = "dev"
use_nat_gateway     = false  # Cost savings - use public subnets
use_alb_waf         = false  # Cost savings - disable WAF
alert_email         = ""     # Optional monitoring
log_retention_days  = { dev = 3 }
```

**Estimated Cost**: ~$50-100/month

#### Staging Environment
```hcl
environment         = "staging"
use_nat_gateway     = true   # Test production networking
use_alb_waf         = false  # Optional
alert_email         = "team@example.com"
log_retention_days  = { staging = 7 }
```

**Estimated Cost**: ~$150-250/month

#### Production Environment
```hcl
environment         = "prod"
use_nat_gateway     = true   # Required for security
use_alb_waf         = true   # Recommended for security
alert_email         = "oncall@example.com"
log_retention_days  = { prod = 30 }
```

**Estimated Cost**: ~$300-500/month (varies by traffic)

### Deployment Steps

1. **Initialize Terraform with Remote State**
```bash
# Set environment variables
export PROJECT_NAME="myapp"
export ENVIRONMENT="prod"
export AWS_REGION="us-east-1"

# Initialize with backend
terraform init \
  -backend-config="bucket=${PROJECT_NAME}-${ENVIRONMENT}-terraform-state" \
  -backend-config="dynamodb_table=${PROJECT_NAME}-${ENVIRONMENT}-terraform-lock" \
  -backend-config="region=${AWS_REGION}" \
  -migrate-state
```

2. **Review and Validate Configuration**
```bash
terraform validate
terraform fmt -check
terraform plan -out=tfplan

# Inspect the plan (tfplan is binary, use terraform show to view)
terraform show tfplan
```

3. **Apply Infrastructure**
```bash
terraform apply tfplan
```

4. **Verify Deployment**
```bash
# Check outputs
terraform output

# Verify critical resources
terraform state list | grep -E "(vpc|alb|ecs_cluster|rds)"
```

5. **Configure DNS**
```bash
# Get name servers from output
terraform output route53_name_servers

# Update your domain registrar with these name servers
```

6. **Confirm SNS Subscription**
   - Check the email specified in `alert_email`
   - Click the confirmation link sent by AWS SNS
   - Verify you receive test notifications

### Post-Deployment Steps

1. **Verify SSL Certificate**
   - Certificate should auto-validate via DNS
   - Check ACM console for validation status
   - May take 5-30 minutes

2. **Test Application Access**
   ```bash
   ALB_DNS=$(terraform output -raw alb_dns_name)
   curl -I https://${ALB_DNS}
   ```

3. **Configure Application**
   ```bash
   # Get database connection strings
   terraform output -raw rds_connection_string
   terraform output -raw elasticache_endpoint
   terraform output -raw documentdb_endpoint
   
   # Get database password
   terraform output -raw database_password
   ```

4. **Deploy Application to ECS**
   - Push Docker images to ECR
   - Update task definitions in `modules/ecs/task-definitions/`
   - Force new deployment:
   ```bash
   aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) \
     --service public_service_01 --force-new-deployment
   ```

5. **Monitor Initial Traffic**
   - Check CloudWatch dashboard
   - Verify alarms are configured
   - Review logs in CloudWatch Logs

### Monitoring and Alerting

#### CloudWatch Alarms Configured

**VPC Monitoring** (1 alarm):
- VPC Flow Logs delivery errors

**ALB Monitoring** (4 alarms):
- 5xx errors > 10 in 5 minutes
- Target response time > 1 second
- Unhealthy targets detected
- Request count anomaly (ML-based)

**Database Monitoring** (11 alarms):
- RDS: CPU, storage, connections, read/write latency (5 alarms)
- ElastiCache: CPU, memory, evictions (3 alarms)
- DocumentDB: CPU, connections, replication lag (3 alarms)

**ECS Monitoring** (5 alarms per service):
- Unhealthy tasks
- CPU utilization > 80%
- Memory utilization > 80%

#### Viewing Metrics

```bash
# List all alarms
aws cloudwatch describe-alarms --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table

# View specific alarm history
aws cloudwatch describe-alarm-history --alarm-name myapp-prod-rds-cpu-high --max-records 10
```

#### CloudWatch Logs

```bash
# ECS service logs
aws logs tail /aws/ecs/${PROJECT_NAME}/services --follow

# VPC Flow Logs
aws logs tail /aws/vpc/${PROJECT_NAME}-flow-logs --follow
```

### Backup and Disaster Recovery

#### Automated Backups

**RDS PostgreSQL**:
- Automated daily backups (retention: 7 days)
- Backup window: 03:00-04:00 UTC
- Manual snapshots: taken before major changes
- Final snapshot: created automatically on deletion

**DocumentDB**:
- Automated daily backups (retention: 7 days)
- Backup window: 02:00-03:00 UTC
- Point-in-time recovery enabled

**ElastiCache**:
- Daily snapshots (retention: 1 day)
- Snapshot window: 00:00-02:00 UTC

#### Manual Backup Procedures

```bash
# Create RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier $(terraform output -raw rds_instance_id) \
  --db-snapshot-identifier ${PROJECT_NAME}-manual-$(date +%Y%m%d-%H%M%S)

# Create DocumentDB snapshot
aws docdb create-db-cluster-snapshot \
  --db-cluster-identifier $(terraform output -raw docdb_cluster_id) \
  --db-cluster-snapshot-identifier ${PROJECT_NAME}-docdb-$(date +%Y%m%d-%H%M%S)

# Create ElastiCache snapshot
aws elasticache create-snapshot \
  --replication-group-id $(terraform output -raw cache_cluster_id) \
  --snapshot-name ${PROJECT_NAME}-cache-$(date +%Y%m%d-%H%M%S)
```

#### Disaster Recovery

**RTO (Recovery Time Objective)**: 1-2 hours
**RPO (Recovery Point Objective)**: 5 minutes (point-in-time recovery)

**Recovery Steps**:
1. Restore from latest automated backup
2. Update DNS if needed
3. Verify data integrity
4. Resume normal operations

### Cost Optimization

#### Current Infrastructure Costs (Estimated)

**Always-On Resources**:
- VPC & Networking: ~$0-5/month (free tier eligible)
- NAT Gateway: ~$32/month (if enabled)
- ALB: ~$16/month + $0.008/LCU-hour
- RDS db.t3.medium: ~$60/month
- ElastiCache cache.t3.medium: ~$30/month
- DocumentDB db.t3.medium: ~$90/month
- ECS Fargate: $0.04/vCPU-hour + $0.004/GB-hour
- CloudWatch Logs: ~$0.50/GB ingested + $0.03/GB stored
- Route53 Hosted Zone: ~$0.50/month
- ACM Certificate: Free

**Optional Resources**:
- WAF: ~$5-10/month + $0.60/million requests
- EC2 t2.micro (spot): ~$3-5/month

**Total Estimated**: $200-400/month (varies by traffic and usage)

#### Cost Optimization Tips

1. **Development Environments**
   - Disable NAT Gateway (`use_nat_gateway = false`)
   - Disable WAF (`use_alb_waf = false`)
   - Use smaller instance types
   - Reduce log retention to 3 days

2. **Staging/Production**
   - Use Reserved Instances for RDS (40-60% savings)
   - Enable S3 lifecycle policies (already configured)
   - Review and right-size ECS task CPU/memory
   - Use Fargate Spot for non-critical workloads

3. **Monitoring**
   - Set up AWS Budgets with alerts
   - Review Cost Explorer monthly
   - Tag all resources for cost allocation

```bash
# Enable AWS Budgets alert
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

### Troubleshooting

#### Common Issues

**1. ACM Certificate Not Validating**
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn $(terraform output -raw acm_certificate_arn)

# Verify DNS records
dig _validation.yourdomain.com TXT

# Solution: Ensure name servers are updated at domain registrar
terraform output route53_name_servers
```

**2. ECS Tasks Not Starting**
```bash
# Check service events
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name) \
  --services public_service_01 --query 'services[0].events[0:5]'

# Common causes:
# - Image not found in ECR
# - Insufficient CPU/memory
# - Task execution role missing permissions
```

**3. Database Connection Failures**
```bash
# Verify security groups allow traffic
aws ec2 describe-security-groups --group-ids $(terraform output -raw db_security_group_id)

# Test from EC2 instance
psql "$(terraform output -raw rds_connection_string)"
```

**4. High AWS Costs**
```bash
# Identify top cost drivers
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Common culprits:
# - NAT Gateway data transfer
# - RDS instance hours
# - CloudWatch Logs storage
```

**5. SNS Alarms Not Received**
```bash
# Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn)

# Status should be "Confirmed", not "PendingConfirmation"
# Check spam folder for confirmation email
```

### Security Best Practices

1. **Credentials Management**
   - Never commit `terraform.tfvars` to git
   - Use AWS Secrets Manager for sensitive data
   - Rotate database passwords regularly

2. **Network Security**
   - Keep resources in private subnets
   - Use security groups with least privilege
   - Enable VPC Flow Logs (already configured)

3. **Monitoring**
   - Enable CloudTrail for audit logging
   - Set up GuardDuty for threat detection
   - Review CloudWatch alarms regularly

4. **Compliance**
   - Enable AWS Config for compliance monitoring
   - Use AWS Security Hub for centralized findings
   - Implement backup retention policies

### Maintenance

#### Regular Tasks

**Daily**:
- Monitor CloudWatch alarms
- Review application logs
- Check for unusual traffic patterns

**Weekly**:
- Review cost reports
- Check for available updates
- Verify backup success

**Monthly**:
- Update base Docker images
- Review and update dependencies
- Conduct security patching
- Review CloudWatch metrics for optimization

**Quarterly**:
- Review disaster recovery plan
- Conduct failover testing
- Security audit
- Cost optimization review

#### Updating Infrastructure

```bash
# Always work in a branch
git checkout -b infrastructure-update

# Make changes to Terraform files
# Run plan to preview changes
terraform plan -out=tfplan

# Review plan carefully (tfplan is a binary file)
terraform show tfplan

# Apply if safe
terraform apply tfplan

# Tag the release
git tag -a v1.2.0 -m "Update: ..."
git push origin v1.2.0
```

### Support and Contributing

For issues, questions, or contributions:
1. Check existing issues
2. Create detailed bug reports
3. Submit pull requests with tests
4. Follow conventional commit messages

---

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
