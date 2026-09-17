"""
Unit tests for the azure-python-devops FastAPI app.

Run locally with:
    cd app
    pytest -v

These same tests are executed automatically by the GitHub Actions
pipeline before any Docker image is built or pushed to ACR.
"""

import sys
import os

# Allow running "pytest" from either the repo root or the app/ directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_read_root():
    """GET / should return 200 with the expected service metadata."""
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "azure-python-devops"
    assert body["version"] == "1.0.0"
    assert "Hello from azure-python-devops" in body["message"]


def test_health_check():
    """GET /health should return 200 with status 'healthy'."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_health_check_content_type():
    """Health endpoint should respond with JSON content type."""
    response = client.get("/health")
    assert response.headers["content-type"] == "application/json"


def test_root_not_found_on_wrong_path():
    """A non-existent path should return 404, confirming routing works as expected."""
    response = client.get("/does-not-exist")
    assert response.status_code == 404
