
# AWS Configuration
aws_region  = "us-east-1"
environment = "dev"

# Project Configuration
project_name     = "license-plate-validator"
container_port   = 8080
container_cpu    = 256
container_memory = 512
desired_count    = 1

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
allowed_cidr_blocks = ["0.0.0.0/0"]

# GitHub Configuration
# Replace with your GitHub username and repo name
github_owner     = "cojocloud"
github_repo_name = "license-plate-lookup"
github_branch    = "main"

# DockerHub Configuration (leave empty to skip DockerHub push)
dockerhub_username = ""

# CodeStar Connection ARN (created once via AWS CLI, approved in console)
# aws codestar-connections create-connection --provider-type GitHub --connection-name license-plate-github --region us-east-1
codestar_connection_arn = "arn:aws:codeconnections:us-east-1:970547342192:connection/120eb9d9-4412-46f7-8b0e-bd52f9e560f1"

# DNS & SSL Configuration
create_dns     = true
domain_name    = "cojocloudsolutions.com"
subdomain      = "license"
enable_alb_ssl = true
