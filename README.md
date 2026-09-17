# Azure Python DevSecOps CI/CD Pipeline

An end-to-end DevSecOps project that automates the build, security scanning, testing, containerization, and deployment of a FastAPI application on Microsoft Azure using GitHub Actions, Docker, and Terraform.

## Project Overview

This project demonstrates a complete DevSecOps pipeline following security-first best practices. Every push to the main branch automatically:

- Scans for leaked secrets (Gitleaks)
- Runs static application security testing (Semgrep SAST)
- Scans Python dependencies for known CVEs (pip-audit)
- Scans Terraform for infrastructure misconfigurations (tfsec)
- Runs unit tests using pytest
- Builds a Docker image
- Scans the built image for vulnerabilities (Trivy) — the build is blocked from publishing if critical/high vulnerabilities are found
- Pushes the scanned image to Azure Container Registry (ACR)
- Cryptographically signs the image (Cosign, keyless via GitHub OIDC)
- Deploys the latest version using Terraform, authenticating to Azure via OIDC federated identity (no long-lived secrets)
- Hosts the application on Azure Container Instance (ACI) and Azure App Service (Linux F1)

## Architecture

```text
GitHub (push or pull_request → main)
            │
            ▼
    secret-scan (Gitleaks)
            │
    ┌───────┼───────────┬──────────────┐
    ▼       ▼            ▼              ▼
   test    sast   dependency-scan    iac-scan
 (pytest) (Semgrep)  (pip-audit)     (tfsec)
    │       │            │              │
    └───────┴────────────┴──────────────┘
                    │
                    ▼
            build-and-push
    ┌──────────────────────────────────┐
    │ Checkout                         │
    │ Compute image tag (Git SHA)      │
    │ Set up Docker Buildx             │
    │ Log in to ACR                    │
    │ Build image (not pushed yet)     │
    │ Trivy scan (blocks on CRIT/HIGH) │
    │ Push image to ACR                │
    │ Install + run Cosign (sign image)│
    └──────────────────────────────────┘
                    │
                    ▼
          terraform-deploy
     (only if: push to main — never on PRs)
    ┌──────────────────────────────────┐
    │ Log in to Azure (OIDC)           │
    │ Terraform init/validate/plan     │
    │ Terraform apply → ACI            │
    │ Update + restart App Service     │
    └──────────────────────────────────┘
                    │
             ┌──────┴──────┐
             ▼             ▼
    Azure Container   Azure App Service
    Instance (ACI)      (Linux F1)
   (pulls via Managed  (pulls via ACR
      Identity)          admin creds)
```

## Tech Stack

**Application**
- Python 3.11, FastAPI, Pytest, Docker

**CI/CD & Infrastructure**
- GitHub Actions, Terraform, Microsoft Azure
- Azure Container Registry (ACR), Azure Container Instance (ACI), Azure App Service (Linux F1)
- Azure Storage Account (Terraform Remote State)
- Azure Managed Identity (ACR image pull, no stored credentials)
- Azure OIDC Federated Identity (GitHub Actions → Azure auth, no long-lived secrets)

**Security (DevSecOps)**
- Gitleaks — secret scanning (CI + local pre-commit hook)
- Semgrep — SAST
- pip-audit — Python dependency vulnerability scanning
- Dependabot — automated dependency update PRs (pip, Docker, GitHub Actions)
- tfsec — Terraform/IaC misconfiguration scanning
- Trivy — container image vulnerability scanning
- Cosign — keyless container image signing via Sigstore/GitHub OIDC

## Project Structure

```text
azure-python-devops/
├── .github/
│   ├── workflows/
│   │   └── deploy.yml
│   └── dependabot.yml
├── app/
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── tests/
│       └── test_main.py
├── infra/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── .terraform.lock.hcl
├── .gitignore
├── .gitleaks.toml
├── .pre-commit-config.yaml
├── SECURITY.md
├── LICENSE
└── README.md
```

## CI/CD Pipeline

The GitHub Actions workflow (`deploy.yml`) runs on every push and pull request against `main`:

**Security gates (run first, block the pipeline on failure):**
- Gitleaks — secret scanning
- Semgrep — SAST
- pip-audit — dependency CVE scanning
- tfsec — Terraform misconfiguration scanning

**Build & scan:**
- Run unit tests (pytest)
- Build Docker image
- Trivy scan of the built image (fails the build on unresolved CRITICAL/HIGH CVEs)
- Push image to Azure Container Registry
- Sign image with Cosign (keyless, via GitHub OIDC)

**Deploy (push to `main` only, not on PRs):**
- Authenticate to Azure via OIDC federated identity
- Terraform init, validate, apply
- Update and restart Azure App Service with the new image

All jobs run on pull requests for validation; only the deploy job is restricted to actual pushes on `main`, so opening a PR never touches live infrastructure.

## Infrastructure as Code

Terraform provisions:

- Azure Resource Group
- Azure Container Registry
- Azure Container Instance
- User-Assigned Managed Identity (grants ACI `AcrPull` access to the registry — no admin password stored or output)
- Remote Terraform State using Azure Storage Account

ACI authenticates to ACR via managed identity rather than registry admin credentials. Terraform no longer outputs any credential values.

## Security & DevSecOps

This pipeline treats security scanning as a required gate, not an afterthought:

| Layer | Tool | What it catches |
|---|---|---|
| Secrets | Gitleaks | API keys, tokens, credentials committed to git — enforced in CI and via a local pre-commit hook |
| Code | Semgrep | Insecure coding patterns (SAST) |
| Dependencies | pip-audit + Dependabot | Known CVEs in Python packages, kept current automatically |
| Infrastructure | tfsec | Terraform misconfigurations (e.g. overly permissive access) |
| Container image | Trivy | OS and Python package vulnerabilities in the built image — blocks the pipeline on unresolved CRITICAL/HIGH findings |
| Supply chain | Cosign | Cryptographically signs every published image via Sigstore's transparency log, using GitHub's OIDC identity — no signing keys stored anywhere |
| Cloud auth | OIDC federated identity | GitHub Actions authenticates to Azure with short-lived tokens, not a stored long-lived secret |
| Access control | Scoped service principal | The CI identity holds `Contributor` only on the specific resource groups it needs, not the whole subscription |
| Supply chain (Actions) | SHA-pinned GitHub Actions | Every third-party action is pinned to an immutable commit SHA rather than a mutable version tag, preventing a compromised/retagged action from silently running in this pipeline |

See [SECURITY.md](SECURITY.md) for the vulnerability reporting policy.

## Application Endpoints

Azure App Service (Linux F1) — primary, always-free
https://azpydevops-webapp.azurewebsites.net/
https://azpydevops-webapp.azurewebsites.net/health

Azure Container Instance
http://azpydevops-app.centralindia.azurecontainer.io:8000/
http://azpydevops-app.centralindia.azurecontainer.io:8000/health

> **Note:** The Azure free trial for this project's subscription has expired, so the live deployments below are currently offline. The pipeline, infrastructure code, and full CI/CD history remain fully functional and viewable — see the [Actions tab](https://github.com/raimadb/azure-python-devops/actions) for live scan/deploy logs, or clone this repo and deploy to your own Azure subscription using the steps below.

Azure App Service (Linux F1)
https://azpydevops-webapp.azurewebsites.net/

Azure Container Instance
http://azpydevops-app.centralindia.azurecontainer.io:8000/

## GitHub Secrets Required

| Secret | Description |
|---------|-------------|
| AZURE_CLIENT_ID | Service principal client ID (used for OIDC federated login) |
| AZURE_TENANT_ID | Azure AD tenant ID |
| AZURE_SUBSCRIPTION_ID | Azure subscription ID |
| REGISTRY_USERNAME | Azure Container Registry username |
| REGISTRY_PASSWORD | Azure Container Registry password |

No long-lived Azure credential secret is used — Azure authentication is handled via OIDC federated identity, configured through an Azure AD federated credential tied to this repository and branch.

## Key Features

- Security-first CI/CD pipeline with 6 automated scanning tools
- Automated CI/CD pipeline with pull-request-level security validation
- Infrastructure as Code with Terraform, remote state in Azure Storage
- OIDC federated authentication (no long-lived Azure secrets in CI)
- Managed identity for container registry access (no stored ACR passwords)
- SHA-pinned GitHub Actions across the entire workflow
- Automated dependency updates via Dependabot
- Container image signing via Cosign/Sigstore
- Dockerized FastAPI application, non-root runtime user, minimal build-tool footprint
- Dual deployment targets: Azure Container Instance and Azure App Service (Linux F1)

## Challenges Faced

During development, I resolved several real-world DevSecOps issues, including:

- Terraform state conflicts when Azure resources already existed
- Migrating Terraform state from local storage to Azure Storage backend
- Diagnosing and fixing a chain of container CVEs across OS packages, Python build tooling, and vendored sub-dependencies (23 findings down to 0)
- Replacing long-lived Azure credentials with OIDC federated identity, including debugging tenant/subject-claim mismatches
- Replacing Azure Container Registry admin credentials with a scoped User-Assigned Managed Identity
- Scoping the CI service principal down from subscription-wide access to specific resource groups
- Resolving a supply-chain incident in a third-party GitHub Action (trivy-action) by migrating to SHA-pinned, immutable action references across the whole pipeline
- Cross-environment tooling issues (Windows/Git Bash vs. WSL Ubuntu) when installing Azure CLI, Terraform, and Gitleaks locally
- Managing Azure free-trial expiration mid-project and adapting the deployment strategy accordingly

## Learning Outcomes

This project strengthened my understanding of:

- DevSecOps pipeline design — treating security scanning as a blocking gate, not an afterthought
- CI/CD pipeline implementation and GitHub Actions workflows
- Docker containerization and container image hardening
- Infrastructure as Code (Terraform), including remote state management
- Azure cloud services, OIDC federated identity, and managed identities
- Azure authentication and role-based access control (RBAC), including least-privilege scoping
- Supply-chain security: image signing, SHA-pinned dependencies, vulnerability scanning
- End-to-end application deployment automation

## Future Improvements

- Sign images by digest rather than tag (Cosign currently signs by tag; digest pinning is stricter)
- Migrate the App Service container pull to managed identity (currently still uses ACR admin credentials, unlike ACI)
- Move tfsec from soft-fail (report-only) to a hard gate once existing findings are triaged
- Integrate SonarQube code quality analysis
- Implement Blue-Green deployment strategy
- Deploy to Azure Kubernetes Service (AKS)
- Add monitoring using Azure Monitor and Application Insights

## CI/CD Optimization

The workflow is configured with `paths-ignore` to prevent deployments when only documentation (`*.md`) files are updated. Security scanning and tests run on every pull request; the deploy stage is restricted to pushes on `main`, so infrastructure is never touched by an open PR.

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/raimadb/azure-python-devops.git
cd azure-python-devops
```

### 2. Configure GitHub Secrets

Add the following repository secrets (see table above):

- AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
- REGISTRY_USERNAME, REGISTRY_PASSWORD

And configure an Azure AD federated credential linking this repository/branch to your service principal for OIDC login.

### 3. (Optional) Set up local pre-commit secret scanning

```bash
pip install pre-commit --break-system-packages
pre-commit install
```

### 4. Push changes

Every push to the main branch runs the full security-gated pipeline: scanning, testing, building, signing, and deploying.

## Author
Raima Deb Barma
