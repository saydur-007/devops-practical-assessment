# DevOps Practical Assessment

A small polyglot microservices sample used for DevOps practical exercises.

## Short Description

This repository contains two simple services to exercise containerization, observability, and deployment workflows.

## Current Progress

- [x] STEP-01 Project structure setup
- [x] STEP-02 Service A implementation
- [x] STEP-03 Service B implementation
- [x] STEP-04 Docker containerization

## Service A (Node.js + Express)

- Location: docker/service-a
- Tech: Node.js, Express
- Endpoints:
	- GET /api/v1/health -> {"status":"healthy","service":"service-a"}
	- GET /api/v1/users -> returns sample users
	- GET /api/v1/error -> returns HTTP 500 (for alert testing)

## Service B (Python + FastAPI)

- Location: docker/service-b
- Tech: Python 3, FastAPI, Uvicorn
- Endpoints:
	- GET /api/v2/health -> {"status":"healthy","service":"service-b"}
	- GET /api/v2/orders -> returns sample orders
	- GET /api/v2/error -> returns HTTP 500 (for alert testing)

## How to run Service B locally (developer)

1. Create a Python virtual environment and activate it:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

2. Install dependencies:

```bash
pip install -r docker/service-b/requirements.txt
```

3. Start the server:

```bash
uvicorn docker.service-b.main:app --host 127.0.0.1 --port 8000
```

4. Test endpoints:

```bash
curl http://127.0.0.1:8000/api/v2/health
curl http://127.0.0.1:8000/api/v2/orders
curl http://127.0.0.1:8000/api/v2/error
```

## STEP-04 Docker containerization notes

This step adds multi-stage Dockerfiles for both services and follows production-oriented best practices:

- Multi-stage builds: build dependencies in a builder image, copy only runtime artifacts into a minimal runtime image.
- Build vs runtime: the builder contains tooling (npm, pip, compilers), the final image is minimal/distroless.
- Minimal/distroless runtime: reduces attack surface and removes shells and package managers from runtime images.
- Non-root execution: final containers are configured to run as UID 10001 (numeric user) to avoid running as root.
- Docker layer caching: package manifests are copied before application code to improve cache reuse during iterative builds.

Service container ports:
- Service A: `8080`
- Service B: `8000`


