# =========================================================================
# Stage 1: builder
# Installs Python dependencies into a virtual environment. Keeping this in
# its own stage means build tools / caches never end up in the final image,
# which keeps the image small (faster pushes/pulls to/from ACR = less
# free-tier bandwidth used).
# =========================================================================
FROM python:3.11-slim AS builder

WORKDIR /build

# Install into an isolated venv so we can copy just the venv into the final
# stage (nothing else from the builder layer is needed at runtime).
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip "setuptools>=78.1.1" "wheel>=0.46.2" && \
    pip install --no-cache-dir -r requirements.txt

# =========================================================================
# Stage 2: runtime
# Small, final image that actually runs in Azure Container Instances / App
# Service. Runs as a non-root user for security best practice.
# =========================================================================
FROM python:3.11-slim AS runtime

# Create a non-root user/group to run the app (never run containers as root)
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser

WORKDIR /app

# Bring in the pre-built virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv
# Build tooling (pip, setuptools, wheel) is only needed to INSTALL dependencies
# during the build — the running app (CMD below) only ever calls uvicorn, never
# pip. Removing build tooling from the shipped image entirely eliminates CVEs
# in pip's own vendored sub-packages, rather than chasing them version by version.
RUN /opt/venv/bin/python -m pip uninstall -y pip setuptools wheel && \
    /usr/local/bin/python3.11 -m pip uninstall -y pip setuptools wheel
ENV PATH="/opt/venv/bin:$PATH"

# Copy application source
COPY main.py .

# Ensure the non-root user owns the app directory
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

# Basic container-level health check (also mirrored by ACI/App Service probes)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
