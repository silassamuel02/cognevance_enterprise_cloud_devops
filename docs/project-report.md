# Project Report: Enterprise Cloud Infrastructure & DevOps Automation

## 1. Project Information

| Field | Details |
|---|---|
| Internship | Cognevance Cloud Computing & DevOps |
| Project | Enterprise Cloud Infrastructure & DevOps Automation |
| Repository | https://github.com/silassamuel02/cognevance_enterprise_cloud_devops |
| Implementation environment | Docker Desktop on Windows |
| Cloud design | AWS using Terraform |
| Current delivery | Local Docker Swarm proof of concept |

## 2. Executive Summary

This project implements a local DevOps proof of concept covering infrastructure-as-code design, container orchestration, CI configuration validation, application health monitoring, metrics visualization, and backup/restore automation.

The local Docker Swarm stack was deployed successfully on a single Docker Desktop node. It runs five services: a Node.js application with two replicas, Prometheus, Grafana, Blackbox Exporter, and Node Exporter. The application's health endpoint returned `healthy`, and the Grafana Enterprise Infrastructure Overview dashboard displayed application probe, scrape-target, and CPU metrics.

Terraform configuration for a proposed AWS environment was created and passed formatting and configuration validation. AWS resources were not provisioned. The CI workflow validates configuration files; it does not perform a cloud or Swarm deployment.

Backup and restore PowerShell scripts have been added to the repository. Their local execution and restore test remain pending and must be recorded before claiming tested disaster recovery.

## 3. Objectives

The project follows the eight areas in the internship brief:

1. Design a scalable cloud architecture using AWS, Azure, or GCP.
2. Implement Infrastructure as Code using Terraform or CloudFormation.
3. Configure Kubernetes or Docker Swarm clusters.
4. Create automated CI/CD workflows.
5. Integrate monitoring and logging using Prometheus and Grafana.
6. Implement security, backups, and disaster recovery.
7. Optimize infrastructure performance and scalability.
8. Document the architecture and deployment process.

## 4. Architecture and Implementation

### 4.1 AWS Architecture Design and Terraform

Terraform is organized into a root configuration and reusable network and compute modules.

The proposed network resources include:
- VPC with DNS support and DNS hostnames.
- Public subnet.
- Internet gateway.
- Public route table and subnet association.

The proposed compute and security resources include:
- Amazon Linux EC2 manager instance and configurable worker instances.
- Security group for application HTTP traffic and Docker Swarm node-to-node ports.
- Optional SSH ingress restricted by an administrator CIDR.
- IAM roles and instance profiles for manager and workers.
- Systems Manager access and a SecureString parameter for the worker join token.
- Encrypted gp3 root volumes and IMDSv2 token enforcement.

**Validation performed:** Terraform formatting, initialization with the backend disabled, and `terraform validate` completed successfully.

**Deployment status:** The Terraform configuration was not applied to AWS. The cloud resources above are an infrastructure design, not a live deployment.

### 4.2 Docker Swarm Application and Services

Docker Swarm was initialized locally using Docker Desktop. The stack is defined in `docker/swarm/stack.yml`.

| Service | Desired replicas | Function |
|---|---:|---|
| Application | 2 | Runs the Node.js application |
| Prometheus | 1 | Collects and stores metrics |
| Grafana | 1 | Displays monitoring dashboards |
| Blackbox Exporter | 1 | Probes the application health endpoint |
| Node Exporter | 1 global task | Exposes host metrics from the Docker Desktop Linux environment |

The stack uses an overlay network, named volumes for Prometheus and Grafana, Docker Swarm secret injection for Grafana credentials, application health checks, restart policies, and service update/rollback settings.

**Observed result:** All five services reached their expected running replica counts on the local Docker Desktop node. The two application replicas ran on the same node; this is service replication, not multi-host high availability.

### 4.3 CI/CD Configuration Validation

The GitHub Actions workflow at `.github/workflows/ci-cd.yml` runs for pushes to main, pull requests targeting main, and manual dispatch.

It validates:
- Terraform formatting.
- Terraform initialization without a remote backend.
- Terraform configuration.
- YAML syntax for workflow, Docker Swarm, and monitoring configuration.
- Grafana dashboard JSON.
- Docker Swarm stack configuration.

The workflow is a **configuration validation pipeline**. It does not build and publish a new application image and does not deploy to AWS or Docker Swarm. The local Swarm deployment was performed manually using Docker CLI commands.

### 4.4 Monitoring and Observability

Prometheus scrapes:
- Its own metrics endpoint.
- Node Exporter.
- Blackbox Exporter probing the application health endpoint.

Grafana is provisioned with a Prometheus data source and an Enterprise Infrastructure Overview dashboard containing:
1. Application Health Probe.
2. Prometheus Scrape Targets.
3. Host CPU Utilization.

**Observed result:** The health endpoint returned `healthy`; the Grafana application probe panel displayed `1`; scrape-target and CPU time-series were visible.

**Scope note:** Node Exporter is reporting metrics from the Docker Desktop Linux environment. It should not be described as a direct measurement of the physical Windows host. The project currently implements metrics and health monitoring, not centralized log aggregation.

### 4.5 Security

Security measures implemented or designed include:
- Grafana administrator credentials injected using a Docker Swarm secret.
- Secret values are not stored in the Git repository.
- Terraform state, plan files, local variable files, and sensitive files are excluded by Git ignore rules.
- AWS IAM roles and optional source-IP-restricted SSH ingress in the Terraform design.
- GitHub Actions uses read-only repository permissions for validation.

The published application and Grafana ports are accessible through the local Docker Desktop host. The local environment should be kept on a trusted machine/network and should not be exposed through a router or public firewall.

### 4.6 Backup and Disaster Recovery

The repository includes:
- `scripts/backup.ps1`
- `scripts/restore.ps1`

The backup script is designed to:
1. Check the expected Grafana and Prometheus Swarm services and record their replica counts.
2. Scale those monitoring services to zero while their persistent volumes are archived.
3. Archive the stack's Grafana and Prometheus data volumes.
4. Create a project configuration ZIP while excluding Terraform state, provider caches, backup output, credentials, and private keys.
5. Write a manifest containing SHA-256 checksums.
6. Restore the original Grafana and Prometheus replica counts in a finally block.

The restore script is designed to validate the manifest and artifact checksums, require the target stack's services to be removed, and require both a command-line confirmation switch and the typed word `RESTORE` before replacing volume contents.

**Important limitations:**
- The backup does not export Docker Swarm secrets. Required external secrets must be created separately.
- The project configuration ZIP is supplementary and is not automatically extracted by the restore script.
- The scripts have been added to GitHub but a successful local backup/restore execution has not yet been recorded. Therefore, disaster recovery is implemented in code but not yet verified through a restore test.

## 5. Validation and Results

| Validation | Result |
|---|---|
| Terraform formatting | Passed |
| Terraform init with backend disabled | Passed |
| Terraform validation | Passed |
| Docker Swarm stack configuration | Passed |
| Docker Swarm service deployment | Five services running |
| Application health endpoint | Returned `healthy` |
| Grafana provisioning | Dashboard appeared under the Enterprise folder |
| Prometheus metrics | Application probe, scrape-target, and CPU metrics visible |
| GitHub Actions configuration workflow | Successful workflow runs observed |
| Backup script execution | Pending local test |
| Restore script execution | Pending local test |
| AWS deployment | Not performed |

## 6. Performance and Scalability

The local application service is configured with two replicas, a health check, restart policy, controlled update behavior, and rollback configuration. Prometheus collects CPU metrics from Node Exporter.

No formal load test, throughput benchmark, autoscaling policy, multi-node scheduling test, or host-failure test has been completed. Because both application replicas run on one Docker Desktop node, the local implementation does not demonstrate host-level fault tolerance.

## 7. Limitations

- AWS resources have not been provisioned or tested in a live AWS account.
- The Docker Swarm cluster has one local node.
- GitHub Actions validates configuration but does not deploy the stack.
- Centralized application/container log aggregation is not configured.
- Backup and restore scripts still require local execution and restore validation.
- Final screenshots and evidence should be added to `docs/screenshots/`.

## 8. Future Improvements

1. Execute and validate the backup and restore scripts.
2. Add screenshots of the running Swarm services, application health endpoint, and Grafana dashboard.
3. Extend the architecture to multiple hosts if cluster-level availability is required.
4. Add centralized log collection.
5. Add workload testing and record performance results.
6. Provision AWS infrastructure only when an approved account and budget are available.

## 9. Conclusion

The project has delivered a working local DevOps proof of concept with Docker Swarm orchestration, application health checks, Prometheus metrics collection, Grafana visualization, Terraform AWS infrastructure definitions, and GitHub Actions configuration validation.

The local deployment and monitoring components were verified. AWS deployment and backup/restore execution remain explicitly identified as unperformed validation activities. This report distinguishes implemented and observed results from planned cloud deployment and untested recovery procedures.
