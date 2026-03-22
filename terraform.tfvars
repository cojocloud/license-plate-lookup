
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

# DockerHub Configuration
# Replace with your DockerHub username
dockerhub_username = "thiexo"
