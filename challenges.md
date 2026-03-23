# Deployment Challenges & Fixes

A record of every error encountered deploying this project to AWS and how each was resolved.

---

## 1. Trailing Space in Terraform Backend Bucket Name

**File:** `terraform/backend.tf`

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket not found
```

**Cause:** The bucket name had a trailing space: `"baho-backup-bucket "`.

**Fix:** Removed the trailing space.
```hcl
bucket = "licenses-plate-bucket"
```

---

## 2. Terraform State Backend Encryption Disabled

**File:** `terraform/backend.tf`

**Cause:** `encrypt = false` — state files contain resource metadata and should always be encrypted at rest.

**Fix:**
```hcl
encrypt = true
```

---

## 3. Hardcoded Project Name in locals.tf Causing Resource Name Mismatches

**File:** `terraform/locals.tf`

**Error:** ECS cluster, service, and container names were built from `"california-plate-validator"` (hardcoded) instead of `var.project_name` (`"license-plate-validator"`). This caused mismatches between what Terraform created and what the pipeline and buildspec referenced.

**Cause:**
```hcl
locals {
  project_name = "california-plate-validator"  # hardcoded from original repo
}
```

**Fix:**
```hcl
locals {
  project_name = var.project_name
}
```

---

## 4. Region Inconsistency Across Files

**Files:** `buildspec.yml`, `terraform/backend.tf`, `terraform/variables.tf`

**Cause:** Three different regions were in use:
- `buildspec.yml` → `us-east-2`
- `terraform/backend.tf` → `us-west-2`
- `terraform/variables.tf` → `us-east-1`

**Fix:** Standardised on `us-east-1` for all application resources. The state backend stays in `us-west-2` (the bucket lives there) which is valid — the state bucket region does not need to match the deployment region.

---

## 5. Broken AWS_ACCOUNT_ID in buildspec.yml

**File:** `buildspec.yml`

**Error:**
```
Error: parameter does not exist
```

**Cause:** The `parameter-store` section in buildspec syntax expects an SSM path, but was being used with a shell command:
```yaml
parameter-store:
  AWS_ACCOUNT_ID: $(aws sts get-caller-identity --query Account --output text)
```

**Fix:** Moved the account ID resolution to `pre_build` using a shell command:
```yaml
pre_build:
  commands:
    - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

---

## 6. Environment Values Mismatch Between CloudFormation and Terraform

**Files:** `pipeline.yml`, `terraform/variables.tf`

**Cause:** The CloudFormation template used `AllowedValues: [development, staging, production]` but Terraform's variable validation required `["dev", "staging", "prod"]`. The environment string passed to CodeBuild from CloudFormation would not match the terraform-created ECS resource names.

**Fix:** Updated `pipeline.yml` to use the same values as Terraform:
```yaml
AllowedValues:
  - dev
  - staging
  - prod
```

---

## 7. Wrong Variable Names in terraform.tfvars

**File:** `scripts/terraform.tfvars`

**Cause:** The original tfvars used `github_repo` with a full URL:
```hcl
github_repo = "https://github.com/cojocloud/license-plate-lookup.git"
```
But `variables.tf` defined `github_owner` (username) and `github_repo_name` (repo name only) as separate variables.

**Fix:**
```hcl
github_owner     = "cojocloud"
github_repo_name = "license-plate-lookup"
```

---

## 8. CloudFormation Stack Failing with ResourceExistenceCheck

**File:** `pipeline.yml`

**Error:**
```
The following hook(s)/validation failed: [AWS::EarlyValidation::ResourceExistenceCheck]
```

**Root Cause:** Terraform had already created `license-plate-validator-build-dev` (CodeBuild) and `license-plate-validator-pipeline-dev` (CodePipeline) via its `codepipeline` module. The CloudFormation `pipeline.yml` tried to create resources with the exact same names — the early validation hook detected the conflict.

**Fix:** Stopped using `pipeline.yml` for deployment entirely. Terraform already provides a complete CI/CD pipeline. The `pipeline.yml` CloudFormation template is kept for reference only.

---

## 9. CloudFormation Stack Stuck in REVIEW_IN_PROGRESS

**Error:**
```
Failed to create the changeset: Waiter ChangeSetCreateComplete failed
```

**Cause:** Failed deployments left the stack in `REVIEW_IN_PROGRESS` state, blocking new deployments.

**Fix:** Delete the stuck stack before retrying:
```bash
aws cloudformation delete-stack --stack-name license-plate-app --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name license-plate-app --region us-east-1
```

---

## 10. GitHub V1 OAuth Validation Failure in CloudFormation

**File:** `pipeline.yml`

**Error:**
```
ResourceExistenceCheck failed
```

**Cause:** AWS CodePipeline's GitHub V1 integration (using OAuth tokens) is deprecated. CloudFormation's early validation rejects it.

**Fix:** Switched `pipeline.yml` to use GitHub V2 via CodeStar Connections (`CodeStarSourceConnection` provider) which is the current AWS-recommended approach.

---

## 11. Missing `codestar-connections:PassConnection` IAM Permission

**Error:**
```
AccessDeniedException: User is not authorized to perform: codestar-connections:PassConnection
```

**Cause:** The IAM user `cloud-engineer` lacked the `PassConnection` permission, which is required when updating a CodePipeline that uses a CodeStar Connection.

**Fix:**
```bash
aws iam put-user-policy \
  --user-name cloud-engineer \
  --policy-name CodeStarConnectionsPass \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "codestar-connections:PassConnection",
        "codestar-connections:UseConnection",
        "codestar-connections:GetConnection",
        "codestar-connections:ListConnections"
      ],
      "Resource": "*"
    }]
  }'
```

---

## 12. CodeBuild Failing to Read SSM Parameter for DockerHub Password

**Error:**
```
parameter does not exist: /license-plate-validator/dev/dockerhub/password
```

**Cause:** The `buildspec.tpl` had a hardcoded `parameter-store` section that always attempted to read the DockerHub password from SSM — even when DockerHub was not being used.

**Fix:** Wrapped the `parameter-store` block in a Terraform conditional:
```
%{ if dockerhub_username != "" ~}
  parameter-store:
    DOCKERHUB_PASSWORD: "/${project_name}/${environment}/dockerhub/password"
%{ endif ~}
```
And set `dockerhub_username = ""` in `terraform.tfvars` to skip DockerHub entirely.

---

## 13. Multiline Shell if Statements Failing in buildspec.tpl

**Error:**
```
exit status 2
```

**Cause:** YAML list items in CodeBuild buildspec collapse multiline strings onto one line. Shell `if` blocks without proper line continuations became invalid syntax:
```yaml
- if ! aws ecr ...; then
    echo "..."
    aws ecr create-repository ...
  fi
```

**Fix:** Used the YAML block scalar (`|`) for multi-line shell blocks:
```yaml
- |
  if [ -n "${dockerhub_username}" ]; then
    docker login ...
  fi
```
Also removed the unnecessary ECR existence check (Terraform already creates the repository).

---

## 14. Wrong imagedefinitions.json Format Breaking ECS Deploy

**Error:**
```
The AWS ECS container license-plate-validator-container-dev does not exist
```

**Cause:** The `imagedefinitions.json` contained extra fields (`essential`, `portMappings`) not accepted by CodePipeline's ECS deploy action:
```json
[{"name":"...","imageUri":"...","essential":true,"portMappings":[...]}]
```

**Fix:** Simplified to the only two fields CodePipeline accepts:
```json
[{"name":"license-plate-validator-container-dev","imageUri":"..."}]
```

---

## 15. Docker Hub Pull Rate Limit in CodeBuild

**Error:**
```
toomanyrequests: You have reached your unauthenticated pull rate limit
```

**Cause:** CodeBuild was pulling `python:3.9-slim` from Docker Hub without authentication. Docker Hub limits unauthenticated pulls to 100 per 6 hours per IP, and CodeBuild shares IPs across many AWS customers.

**Fix:** Changed the Dockerfile base image to the ECR Public Gallery mirror, which has no rate limits for pulls from within AWS:
```dockerfile
FROM public.ecr.aws/docker/library/python:3.9-slim
```

---

## 16. CodeBuild Image `standard:5.0` Deprecated

**File:** `terraform/modules/codepipeline/main.tf`

**Cause:** `aws/codebuild/standard:5.0` (Ubuntu 18.04) is deprecated and CloudFormation/Terraform's resource validation may reject it.

**Fix:**
```hcl
image = "aws/codebuild/standard:7.0"
```

---

## 17. Pipeline Not Auto-Triggering on Git Push

**Cause 1:** The CodePipeline was created as type V1, which does not support the `trigger` block required for CodeStar Connection webhooks.

**Fix 1:** Set `pipeline_type = "V2"` and added an explicit trigger:
```hcl
resource "aws_codepipeline" "main" {
  pipeline_type = "V2"
  ...
  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = [var.github_branch]
        }
      }
    }
  }
}
```

**Cause 2:** The CodeStar Connection was authorized against the user's personal GitHub account but the repository lives in the `cojocloud` organization. The AWS GitHub App was never granted access to that org.

**Fix 2:** Grant org access in GitHub:
1. Go to `github.com/settings/apps/authorizations`
2. Find **AWS Connector for GitHub** → **Configure**
3. Under **Organization access** → click **Grant** next to the org

---

## 18. Terraform-Created CodeStar Connection Used Wrong Connection

**Cause:** Terraform's `codepipeline` module creates its own CodeStar Connection when `codestar_connection_arn = ""`. The Terraform-created connection was in PENDING state (never approved), while a separate manually-created connection was AVAILABLE.

**Fix:** Pass the AVAILABLE connection ARN to Terraform so it uses the approved one:
```hcl
# terraform.tfvars
codestar_connection_arn = "arn:aws:codestar-connections:us-east-1:ACCOUNT:connection/ID"
```
```bash
terraform apply -var-file="../terraform.tfvars"
```

---

## 19. CodePipeline Deploy Stage: Role Does Not Have Sufficient Permissions to Access ECS

**File:** `terraform/modules/codepipeline/main.tf`

**Error:**
```
The provided role does not have sufficient permissions to access ECS
```

**Cause:** The CodePipeline IAM role was missing `ecs:TagResource`, which the ECS deploy action requires when registering a new task definition.

**Fix:** Added `ecs:TagResource` to the CodePipeline role's ECS permission block:
```hcl
"ecs:TagResource",
```
