# License Plate Validator — AWS Pipeline Deployment

A California license plate validation web application deployed on AWS ECS Fargate with a fully automated CI/CD pipeline.

---

## Architecture Overview

```
GitHub ──► CodePipeline ──► CodeBuild ──► ECR ──► ECS Fargate
                                                       │
                                              Application Load Balancer
                                                       │
                                                   End Users
```

**AWS Services used:**
- **CodePipeline** — orchestrates the CI/CD flow (Source → Build → Deploy)
- **CodeBuild** — builds the Docker image and pushes to ECR
- **ECR** — stores Docker images
- **ECS Fargate** — runs the containerized Flask application
- **Application Load Balancer** — routes traffic to ECS tasks
- **VPC** — isolated network with public/private subnets across 2 AZs
- **NAT Gateway** — allows ECS tasks in private subnets to reach the internet
- **CloudWatch** — logs and monitoring
- **S3** — Terraform state backend + CodePipeline artifact store
- **DynamoDB** (optional) — Terraform state lock table

---

## Deployment Overview

There are **two separate deployments**:

| Step | What | Tool |
|------|------|------|
| 1 | Deploy ECS infrastructure (VPC, ECS cluster, ALB, ECR, IAM) | Terraform |
| 2 | Deploy CI/CD pipeline (CodePipeline + CodeBuild) | CloudFormation (`pipeline.yml`) |

After both are deployed, every `git push` to `main` automatically triggers a new build and deploys the updated container to ECS.

---

## Prerequisites

Before starting, ensure you have the following installed and configured:

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) — configured with `aws configure`
- [Terraform >= 1.0](https://developer.hashicorp.com/terraform/install)
- A GitHub account with this repository forked or cloned
- A DockerHub account (optional — only needed if pushing to DockerHub in addition to ECR)
- An existing S3 bucket for Terraform state (`license-plate-bucket` in `us-east-1`)

---

## Create the Terraform State S3 Bucket

Run this once before your first `terraform init`. The bucket must exist before Terraform can use it as a backend.

```bash
# Create the bucket
aws s3api create-bucket \
  --bucket licenses-plate-bucket \
  --region us-east-1

# Enable versioning (allows state file recovery)
aws s3api put-bucket-versioning \
  --bucket licenses-plate-bucket \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket licenses-plate-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket licenses-plate-bucket \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Verify the bucket is ready:
```bash
aws s3api get-bucket-versioning --bucket licenses-plate-bucket
aws s3api get-bucket-encryption --bucket licenses-plate-bucket
```

---

## Step-by-Step Deployment

### Step 1 — Fill in your credentials

Before deploying, update the following placeholders across the configuration files:

#### `terraform.tfvars`
```hcl
github_owner       = "YOUR_GITHUB_USERNAME"   # your GitHub username
github_repo_name   = "license-plate-lookup"   # your repo name
dockerhub_username = "YOUR_DOCKERHUB_USERNAME"
```

#### `pipeline.yml` (CloudFormation parameters)
The `GitHubOwner` default is `YOUR_GITHUB_USERNAME` — you will override this when deploying the stack (see Step 3).

#### `terraform/variables.tf`
Update the defaults for `github_owner` and `dockerhub_username` to match your accounts, or pass them via `terraform.tfvars`.

---

### Step 2 — Deploy Infrastructure with Terraform

This deploys the VPC, ECS cluster, ALB, ECR repository, and IAM roles.

```bash
cd terraform

# Initialize Terraform (downloads providers, connects to S3 backend)
terraform init

# Preview what will be created
terraform plan -var-file="../scripts/terraform.tfvars"

# Deploy infrastructure (~5-10 minutes)
terraform apply -var-file="../scripts/terraform.tfvars"
```

> **Sensitive variables** — pass `github_token` and `dockerhub_password` on the command line to avoid storing them in files:
> ```bash
> terraform apply \
>   -var-file="../scripts/terraform.tfvars" \
>   -var="github_token=ghp_xxxxxxxxxxxx" \
>   -var="dockerhub_password=YOUR_DOCKERHUB_TOKEN"
> ```

After `apply` completes, note the outputs — especially:
- `ecr_repository_url` — used by CodeBuild
- `alb_dns_name` — the URL where the app will be accessible

---

### Step 3 — Deploy the CI/CD Pipeline with CloudFormation

The `pipeline.yml` CloudFormation template creates **CodePipeline** and **CodeBuild**.

```bash
aws cloudformation deploy \
  --template-file pipeline.yml \
  --stack-name license-plate-validator-pipeline \
  --capabilities CAPABILITY_IAM \
  --region us-east-1 \
  --parameter-overrides \
      Environment=dev \
      GitHubOwner=YOUR_GITHUB_USERNAME \
      GitHubRepo=license-plate-lookup \
      GitHubBranch=main \
      GitHubToken=ghp_xxxxxxxxxxxx
```

> **Generating a GitHub token:**
> Go to GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic)
> Create a token with scopes: `repo`, `admin:repo_hook`

To verify the stack was created:
```bash
aws cloudformation describe-stacks \
  --stack-name license-plate-validator-pipeline \
  --region us-east-1 \
  --query "Stacks[0].StackStatus"
```

---

### Step 4 — Trigger the First Pipeline Run

The pipeline triggers automatically on every push to `main`. To trigger it manually:

```bash
aws codepipeline start-pipeline-execution \
  --name license-plate-validator-pipeline-dev \
  --region us-east-1
```

Or simply push a commit:
```bash
git add .
git commit -m "trigger initial deployment"
git push origin main
```

---

### Step 5 — Monitor the Pipeline

**Via AWS Console:**
1. Go to **CodePipeline** → `license-plate-validator-pipeline-dev`
2. Watch the three stages: **Source** → **Build** → **Deploy**

**Via CLI:**
```bash
aws codepipeline get-pipeline-state \
  --name license-plate-validator-pipeline-dev \
  --region us-east-1
```

**Build logs:**
```bash
# List recent builds
aws codebuild list-builds-for-project \
  --project-name license-plate-validator-build-dev \
  --region us-east-1

# View logs in CloudWatch
aws logs tail /aws/codebuild/license-plate-validator-dev --follow
```

---

### Step 6 — Access the Application

Once the Deploy stage completes, get the ALB DNS name:

```bash
terraform -chdir=terraform output alb_dns_name
```

Open the URL in your browser:
```
http://<alb-dns-name>
```

The app provides:
- **`/`** — Web UI for validating California license plates
- **`/api/validate`** — POST endpoint for single plate validation
- **`/api/bulk-validate`** — POST endpoint for batch validation
- **`/api/health`** — Health check (used by ALB)
- **`/api/formats`** — List of all supported plate formats

---

## Resource Naming Convention

All resources follow this pattern: `{project_name}-{resource_type}-{environment}`

| Resource | Name |
|----------|------|
| ECS Cluster | `license-plate-validator-cluster-dev` |
| ECS Service | `license-plate-validator-service-dev` |
| Container | `license-plate-validator-container-dev` |
| ECR Repository | `license-plate-validator-dev` |
| ALB | `license-plate-validator-dev-alb` |
| CodePipeline | `license-plate-validator-pipeline-dev` |
| CodeBuild Project | `license-plate-validator-build-dev` |
| CloudWatch Log Group | `/ecs/license-plate-validator-dev` |

---

## Configuration Reference

### `scripts/terraform.tfvars`
| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for all resources | `us-east-1` |
| `environment` | Environment name (`dev`, `staging`, `prod`) | `dev` |
| `project_name` | Base name for all resources | `license-plate-validator` |
| `container_port` | Port the Flask app listens on | `8080` |
| `container_cpu` | Fargate CPU units (256 = 0.25 vCPU) | `256` |
| `container_memory` | Fargate memory in MiB | `512` |
| `desired_count` | Number of ECS tasks | `1` |
| `github_owner` | Your GitHub username | — |
| `github_repo_name` | Your GitHub repository name | `license-plate-lookup` |
| `github_branch` | Branch to trigger pipeline | `main` |
| `dockerhub_username` | DockerHub username | — |

### Terraform State Backend (`terraform/backend.tf`)
| Setting | Value |
|---------|-------|
| S3 Bucket | `baho-backup-bucket` |
| Key | `terraform-state-file/ca-lic-plate` |
| Region | `us-west-2` |
| Encryption | `true` |

> The state bucket region (`us-west-2`) can differ from the deployment region (`us-east-1`).

---

## Teardown

To destroy all resources:

```bash
# 1. Delete the CloudFormation pipeline stack
aws cloudformation delete-stack \
  --stack-name license-plate-validator-pipeline \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name license-plate-validator-pipeline \
  --region us-east-1

# 2. Destroy all Terraform-managed infrastructure
cd terraform
terraform destroy -var-file="../scripts/terraform.tfvars"
```

> **Note:** ECR has `force_delete = true` so the repository and all images are deleted automatically. The Terraform state S3 bucket (`baho-backup-bucket`) is NOT managed by Terraform and will not be deleted.

---

## Troubleshooting

**Pipeline fails at Build stage — ECR login error**
- Verify the CodeBuild IAM role has `ecr:GetAuthorizationToken` permission (already in `pipeline.yml`)
- Check that the ECR repository exists: `aws ecr describe-repositories --region us-east-1`

**Pipeline fails at Deploy stage — ECS service not found**
- Confirm Terraform was applied before deploying the pipeline
- Check cluster/service names match: `aws ecs list-services --cluster license-plate-validator-cluster-dev`

**ALB returns 503**
- ECS task may still be starting (wait ~2 minutes after deployment)
- Check task health: `aws ecs describe-tasks --cluster license-plate-validator-cluster-dev --tasks $(aws ecs list-tasks --cluster license-plate-validator-cluster-dev --query taskArns[0] --output text)`
- Check CloudWatch logs: `aws logs tail /ecs/license-plate-validator-dev --follow`

**Terraform init fails — S3 backend not found**
- Ensure the `baho-backup-bucket` S3 bucket exists in `us-west-2` before running `terraform init`
- Create it if needed: `aws s3 mb s3://baho-backup-bucket --region us-west-2`
