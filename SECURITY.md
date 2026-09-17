# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it
by opening a private security advisory on GitHub:

https://github.com/raimadb/azure-python-devops/security/advisories/new

Please do not open a public issue for security vulnerabilities.

## Scope

This is a personal portfolio/learning project. It runs on Azure free-tier
services and is not intended for production use with sensitive data.

## Security Measures in Place

This repository's CI/CD pipeline includes automated security scanning:
- **Gitleaks** — secret detection (CI + local pre-commit hook)
- **Semgrep** — static application security testing (SAST)
- **pip-audit** — Python dependency vulnerability scanning
- **tfsec** — Terraform/IaC misconfiguration scanning
- **Trivy** — container image vulnerability scanning
- **Cosign** — container image signing (keyless, via GitHub OIDC)

Azure authentication uses OIDC federated identity rather than long-lived
credentials, and container image pulls use Azure managed identity rather
than registry admin credentials.
