"""
azure-python-devops - FastAPI application

A minimal, production-shaped FastAPI service with two endpoints:
  - GET /       -> basic service info (used for smoke checks / demos)
  - GET /health -> health probe (used by container orchestrators, ACI/App Service
                   restart policies, and monitoring tools to know the app is alive)
"""

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(
    title="azure-python-devops",
    description="Sample FastAPI service deployed to Azure via free-tier services",
    version="1.0.0",
)


class RootResponse(BaseModel):
    message: str
    service: str
    version: str


class HealthResponse(BaseModel):
    status: str


@app.get("/", response_model=RootResponse)
def read_root() -> RootResponse:
    """Root endpoint - confirms the service is reachable."""
    return RootResponse(
        message="Hello from azure-python-devops running on Azure!",
        service="azure-python-devops",
        version="1.0.0",
    )


@app.get("/health", response_model=HealthResponse)
def health_check() -> HealthResponse:
    """Health endpoint - used by Azure Container Instances / App Service /
    GitHub Actions smoke tests to verify the app started correctly."""
    return HealthResponse(status="healthy")
