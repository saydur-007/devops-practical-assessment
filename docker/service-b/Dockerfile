# Service B multi-stage Dockerfile
# Builder stage: use official Python slim image to install dependencies
FROM python:3.12-slim AS builder
WORKDIR /app

# Install pip dependencies into an isolated location to copy into final image
COPY requirements.txt ./
RUN python -m pip install --upgrade pip setuptools wheel \
    && python -m pip install --prefix=/install -r requirements.txt

# Copy application files
COPY main.py ./

# Final stage: use Distroless Python runtime for minimal attack surface
FROM gcr.io/distroless/python3:3.12
WORKDIR /app

# Copy installed packages from builder into the final image's site-packages
COPY --from=builder /install /usr/local

# Copy application code
COPY --from=builder /app /app

# Expose application port
EXPOSE 8000

# Run as non-root numeric user 10001 (distroless has no user creation tools)
USER 10001

# Start the application using Uvicorn. Bind to 0.0.0.0 for container networking.
ENTRYPOINT ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
