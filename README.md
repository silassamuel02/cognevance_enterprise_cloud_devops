# Enterprise Cloud Infrastructure & DevOps Automation

A DevOps infrastructure project developed as part of the Cognevance Cloud Computing & DevOps Internship.

## Project Overview

This project demonstrates Infrastructure as Code, container orchestration, CI/CD configuration validation, application health monitoring, metrics collection, and dashboard visualization.

**Implementation status:** Local Docker Swarm proof of concept successfully deployed and tested.

**Cloud deployment status:** AWS infrastructure is defined using Terraform but has not been provisioned. The implementation currently runs locally using Docker Desktop.

## Technology Stack

| Category | Technology |
|---|---|
| Infrastructure as Code | Terraform |
| Cloud Infrastructure Design | AWS |
| Containerization | Docker |
| Container Orchestration | Docker Swarm |
| CI/CD | GitHub Actions |
| Container Registry | Docker Hub |
| Metrics Collection | Prometheus |
| Monitoring Dashboard | Grafana |
| Health Monitoring | Prometheus Blackbox Exporter |
| System Metrics | Node Exporter |
| Automation | PowerShell |

## Implemented Features

### 1. Infrastructure as Code

Terraform configuration defines the proposed AWS infrastructure, including:

- Virtual Private Cloud (VPC).
- Public subnet and internet gateway.
- Route table and network configuration.
- EC2 manager and worker instances.
- Security groups.
- IAM roles and policies.
- Secure Swarm worker-token distribution using AWS Systems Manager Parameter Store.

Terraform formatting, initialization without a backend, and configuration validation were completed successfully.

**Note:** These resources have not been deployed to AWS.

### 2. Docker Swarm Orchestration

A local Docker Swarm cluster was initialized using Docker Desktop.

The stack contains five services:

| Service | Replicas | Purpose |
|---|---:|---|
| Application | 2 | Runs the Node.js application |
| Prometheus | 1 | Collects metrics |
| Grafana | 1 | Displays monitoring dashboards |
| Blackbox Exporter | 1 | Checks application availability |
| Node Exporter | 1 | Collects system metrics |

Additional configurations include health checks, restart policies, overlay networking, service update policies, and Docker secrets.

### 3. CI/CD Configuration Validation

GitHub Actions automatically validates infrastructure configuration when changes are pushed to the repository.

The workflow checks:

- Terraform formatting.
- Terraform initialization and validation.
- YAML configuration syntax.
- Grafana dashboard JSON.
- Docker Swarm stack configuration.

This workflow performs configuration validation. It does not automatically deploy infrastructure to AWS or Docker Swarm.

### 4. Monitoring and Visualization

Prometheus collects metrics from configured monitoring targets.

Grafana uses Prometheus as its data source and provisions an Enterprise Infrastructure Overview dashboard.

The dashboard contains three panels:

- Application Health Probe.
- Prometheus Scrape Targets.
- Host CPU Utilization.

The application health endpoint was tested successfully and returned `healthy`.

### 5. Security

Security-related configurations include:

- Docker Swarm secrets for Grafana credentials.
- No hardcoded Grafana administrator password in the repository.
- AWS IAM roles and restricted infrastructure access in the Terraform design.
- GitHub Actions read-only repository permissions.
- Git ignore rules for Terraform state, plans, credentials, and sensitive files.

## Project Structure

```text
cognevance_enterprise_cloud_devops/
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml
│
├── terraform/
│   ├── modules/
│   │   ├── compute/
│   │   └── network/
│   ├── providers.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── docker/
│   └── swarm/
│       └── stack.yml
│
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       ├── dashboards/
│       └── provisioning/
│
├── scripts/
│   ├── validate.ps1
│   ├── deploy.ps1
│   ├── backup.ps1
│   └── restore.ps1
│
├── docs/
│   ├── architecture/
│   ├── screenshots/
│   └── project-report.md
│
├── backups/
├── .gitignore
└── README.md
```

## Local Deployment

### Prerequisites

- Windows with Docker Desktop.
- Docker CLI and Docker Swarm support.
- Terraform CLI.
- Docker Hub access to pull the application image.

### Step 1: Initialize Docker Swarm

```powershell
docker swarm init
```

Run this only if Swarm has not already been initialized.

### Step 2: Create the Grafana Secret

Create an external Docker Swarm secret named:

```text
grafana_admin_password
```

Use your own private password. Do not commit the password or its source file to GitHub.

### Step 3: Validate and Deploy the Stack

From the repository root:

```powershell
cd docker/swarm

docker stack config --compose-file .\stack.yml

docker stack deploy --compose-file .\stack.yml cognevance
```

### Step 4: Verify Services

```powershell
docker stack services cognevance
```

### Step 5: Access the Application and Dashboard

| Component | Local URL |
|---|---|
| Application health | http://localhost/health |
| Grafana dashboard | http://localhost:3000 |

Log in to Grafana using the administrator credentials configured through the Docker secret.

### Step 6: Remove the Stack

```powershell
docker stack rm cognevance
```

## Terraform Validation

From the repository root:

```powershell
cd terraform

terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

The optional AWS deployment script includes an explicit confirmation before Terraform apply. AWS credentials and an appropriately configured AWS account would be required.

**Do not run Terraform apply unless AWS resource costs have been reviewed and deployment is intended.**

## Backup and Restore

The project includes PowerShell scripts for the local Swarm monitoring data:

- `scripts/backup.ps1` pauses Grafana and Prometheus, archives their named volumes, creates a project-configuration ZIP, writes SHA-256 checksums, and restores the original service replica counts.
- `scripts/restore.ps1` verifies the manifest and checksums before restoring the Grafana and Prometheus volumes. It requires the stack services to be removed, the `-ConfirmRestore` switch, and the typed confirmation `RESTORE`.

Run a backup from the repository root:

```powershell
.\scripts\backup.ps1
```

Restore only when necessary. First remove the stack and wait until its services disappear:

```powershell
docker stack rm cognevance
```

Then supply the exact backup directory:

```powershell
.\scripts\restore.ps1 -BackupPath .\backups\cognevance-YYYYMMDD-HHMMSSZ -ConfirmRestore
```

The restore replaces the contents of the two monitoring volumes. Review the backup path carefully. Docker Swarm secrets are not exported; the external `grafana_admin_password` secret must be available separately before redeploying. The configuration ZIP is not automatically extracted.

**Testing status:** The backup and restore scripts are implemented; local execution and restore validation are still pending.

## Validation Results

The following local checks were completed successfully:

- Terraform formatting and validation.
- Docker Swarm stack configuration validation.
- Five Docker Swarm services running.
- Two application replicas running.
- Application health endpoint returning `healthy`.
- Grafana dashboard automatically provisioned.
- Prometheus metrics visible in Grafana.
- GitHub Actions infrastructure validation workflow passed, including PowerShell syntax checks.

## Limitations and Future Improvements

- Actual AWS infrastructure deployment has not been performed.
- The local Swarm setup uses a single Docker Desktop node, not a multi-host high-availability cluster.
- Node Exporter metrics represent the Docker Desktop Linux environment, not necessarily the physical Windows host.
- Backup and restore scripts still require a successful local execution and recovery test.
- Production deployment, centralized logging, disaster recovery testing, and multi-node failure testing remain future improvements.

## Internship Information

**Organization:** Cognevance  
**Project:** Enterprise Cloud Infrastructure & DevOps Automation  
**Repository:** [GitHub Repository](https://github.com/silassamuel02/cognevance_enterprise_cloud_devops)

This project demonstrates practical DevOps concepts through a locally deployed and validated infrastructure proof of concept, with an AWS Terraform design for future cloud deployment.
