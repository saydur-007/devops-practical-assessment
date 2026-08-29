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

Service B runtime note:
- Distroless Python (`gcr.io/distroless/python3:3.12`) was considered and preferred for minimal attack surface.
- In environments where the distroless manifest is not available, this repository falls back to `python:3.12-slim` as a minimal, compatible runtime. Build tools and dependencies remain isolated in the builder stage at `/install` and are copied into the final image only as needed.

Images built locally (after verification):
- `devops-service-a:step04` — 204MB
- `devops-service-b:step04` — 159MB

Example Docker build and run commands:

```bash
# From repository root
docker build -f docker/service-a/Dockerfile -t devops-service-a:step04 docker/service-a
docker run --rm -p 8080:8080 --name t-service-a devops-service-a:step04

docker build -f docker/service-b/Dockerfile -t devops-service-b:step04 docker/service-b
docker run --rm -p 8000:8000 --name t-service-b devops-service-b:step04
```

Multi-stage build explanation:
- The builder stage installs dependencies and compiles or prepares artifacts. The final runtime stage copies only the minimal runtime artifacts needed to run the app (application code and installed packages), keeping image size and attack surface small.

Build vs runtime image:
- Builder: contains package managers and build tools (`npm`, `pip`) and the full dependency installation step.
- Runtime: contains only the runtime interpreter and the application artifacts copied from the builder stage; runs as non-root `UID 10001` and exposes the runtime port.


