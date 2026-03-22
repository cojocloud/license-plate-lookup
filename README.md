# 🚗 California License Plate Validator

A cloud-native application that validates California license plate numbers with a complete CI/CD pipeline on AWS.

## 📋 Features

- **Plate Validation**: Validates California license plates from 1914 to present
- **Multiple Formats**: Supports all historical and modern plate formats
- **RESTful API**: JSON API for programmatic access
- **Web Interface**: Modern, responsive web application
- **Real-time Validation**: Stream validation results
- **Bulk Validation**: Validate multiple plates at once
- **Random Plate Generation**: Generate valid California plates

## 📌 Overview

This project demonstrates a production-grade cloud-native application deployed on AWS using Terraform, Docker, ECS, and CI/CD pipelines. The application validates California license plates via a Flask web interface and is fully automated from infrastructure provisioning to deployment.

## ❓ Problem Statement

Manual application deployments are error-prone, non-scalable, and difficult to maintain. This project solves that by implementing:

**Infrastructure as Code**

**Containerized workloads**

**Automated CI/CD pipelines**

**Scalable and resilient AWS services**

## 🛠 Technology Stack

- Cloud: AWS (ECS, ECR, ALB, VPC, CodePipeline, CodeBuild)

- IaC: Terraform (modular)

- Backend: Python Flask

- Containers: Docker

- CI/CD: AWS CodePipeline

- Version Control: GitHub

## 🏗 Architecture

VPC with public subnets

Application Load Balancer

ECS Fargate service

Docker images stored in ECR

CI/CD pipeline for automated deployments

## 📂 Project Structure

```

CA-LIC-PLATE/
├── app/
│   ├── app.py
│   ├── plate_validator.py
│   ├── requirements.txt 
│   └── templates/
│       └── index.html
├── Docker/
│   └──  Dockerfile
├── scripts/
│   ├── build.sh
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── run-docker-local.sh
│   ├── run-local.sh
|   └── setup.sh 
│           
├── terraform/
│       ├── backend.tf
│       ├── locals.tf
|       |-- main.tf 
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       └── variables.tf
│       └── versions.tf
│       └── modules/
│              ├── codepipeline/  
│                  ├── main.tf
│                  ├── outputs.tf
|                  |-- variables.tf 
│                  └── buildspec.tpl
│              ├── ecs/
│                  ├── main.tf
│                  ├── outputs.tf
│                  ├── variables
│                  └── task-definition.tf
│              └── networking
│                  ├── main.tf.tf
│                  ├── providers.tf
│                  ├── outputs.tf
│                  └── variables.tf
│
│
│--- .env
│
|--- buildspec.yml
│
|--- pipeline.yml
|
└── README.md

```

## 🚀 Deployment Instructions manually

### 📦 Step 1: Clone Repository

```bash
git clone https://github.com/Joebaho/CA-LIC-PLATE.git
cd "CA-LIC-PLATE"
```

### 🔧 Step 2: Configure Variables

Edit:

terraform/terraform.tfvars and all values in the env folder.

Set values in the variables:

AWS region

Project name

CIDR blocks

GitHub repo info (for pipeline)

Dockerhub info

### 🚀 Step 3: Deploy Infrastructure manually

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

### 🐳 Step 4: Build & Push Docker Image manually

```bash
cd ..
chmod +x scripts/build.sh
./scripts/build.sh
```

### 🔁 Step 5: Deploy Application manually

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

This will:

Push image to ECR

Trigger ECS deployment

Pipeline will handle updates

### 🌍 Step 6: Access the App

Retrieve ALB DNS name from Terraform outputs:

terraform output alb_dns_name

Copy the value, Open in browser and paste that there you will get the webpage

## Running docker locally

```bash
cd scripts
chmod +x run-docker-local.sh
./run-docker-local.sh
```

## Running all project local

```bash
cd scripts
chmod +x run-local.sh
./run-local
```

## Running the entire project with automation

```bash
TF_BACKEND_BUCKET="california-plate-validator-tfstate-$(aws sts get-caller-identity --query Account --output text)" \
ENVIRONMENT=dev \
scripts/deploy.sh full
```


## 🧹 Destruction

To destroy the entire project manually type command **terraform destroy** 

```bash
cd terraform
terraform destroy --auto-approve
```

Either with automation you can just type

```bash
TF_BACKEND_BUCKET="california-plate-validator-tfstate-$(aws sts get-caller-identity --query Account --output text)" \
ENVIRONMENT=dev \
PURGE_BACKEND=true \
scripts/destroy.sh
```

## 🎓 Learning Outcomes

Real-world Terraform modular design

ECS Fargate deployments

CI/CD pipeline automation

Secure cloud architecture practices

End-to-end DevOps workflow

## 📚 Resources

Terraform Docs

AWS ECS Documentation

Docker Best Practices

Flask Documentation

## 🤝 Contribution

Pull requests are welcome. For major changes, please open an issue first.

## 👨‍💻 Author

**Joseph Mbatchou**

• DevOps / Cloud / Platform  Engineer   
• Content Creator / AWS Builder

## 🔗 Connect With Me

🌐 Website: [https://platform.joebahocloud.com](https://platform.joebahocloud.com)

💼 LinkedIn: [https://www.linkedin.com/in/josephmbatchou/](https://www.linkedin.com/in/josephmbatchou/)

🐦 X/Twitter: [https://www.twitter.com/Joebaho237](https://www.twitter.com/Joebaho237)

▶️ YouTube: [https://www.youtube.com/@josephmbatchou5596](https://www.youtube.com/@josephmbatchou5596)

🔗 Github: [https://github.com/Joebaho](https://github.com/Joebaho)

📦 Dockerhub: [https://hub.docker.com/u/joebaho2](https://hub.docker.com/u/joebaho2)

---

## 📄 License

This project is licensed under the MIT License — see the LICENSE file for details.