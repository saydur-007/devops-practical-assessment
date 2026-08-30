# DevOps Practical Assessment

A small polyglot microservices sample used for DevOps practical exercises.

## Short Description

This repository contains two simple services to exercise containerization, observability, and deployment workflows.

## Current Progress

- [x] STEP-01 Project structure setup
- [x] STEP-02 Service A implementation
- [x] STEP-03 Service B implementation
- [x] STEP-04 Docker containerization
- [x] STEP-05 Local Kubernetes cluster setup
- [x] STEP-06 Kubernetes application deployment
- [x] STEP-07 Kubernetes horizontal pod autoscaling

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

## STEP-05 Local Kubernetes cluster (kind)

- Cluster name: `devops-assessment`
- Node topology: 1 control-plane, 2 workers
- Host port mappings configured on control-plane node: host `80` -> container `80`, host `443` -> container `443`
- The cluster is local (kind) and intended for assessment validation; services are not deployed by default.

Create the cluster:

```bash
kind create cluster --name devops-assessment --config k8s/kind-config.yaml
```

Delete the cluster:

```bash
kind delete cluster --name devops-assessment
```

Validation commands:

```bash
kubectl cluster-info --context kind-devops-assessment
kubectl get nodes -o wide
kubectl config current-context
```

### Cluster Verification

The following screenshot shows the cluster verification output (`kubectl get nodes -o wide`) used during validation:

![3-Node Kind Cluster Verification](docs/screenshots/step-05-kind-cluster.png)

## STEP-06 Kubernetes application deployment

- Namespace: `default`
- Deployments: `service-a`, `service-b`
- Replicas: 2 each
- Resource requests: `cpu: 100m`, `memory: 128Mi`
- Resource limits: `cpu: 500m`, `memory: 256Mi`
- Service A health probe: `/api/v1/health`
- Service B health probe: `/api/v2/health`
- Rolling update: `maxSurge: 25%`, `maxUnavailable: 0`
- Pod anti-affinity: `requiredDuringSchedulingIgnoredDuringExecution`
- Topology key: `kubernetes.io/hostname`

Apply manifests (from repo root):

```bash
kubectl apply -f k8s/base/service-a/deployment.yaml
kubectl apply -f k8s/base/service-a/service.yaml
kubectl apply -f k8s/base/service-b/deployment.yaml
kubectl apply -f k8s/base/service-b/service.yaml
```

Verify deployments and pods:

```bash
kubectl get deployments
kubectl get pods -o wide
kubectl get svc
```

Port-forward for testing (run in separate terminals):

```bash
# Service A
kubectl port-forward svc/service-a 8080:8080 --address 127.0.0.1
# Service B
kubectl port-forward svc/service-b 8000:8000 --address 127.0.0.1
```

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
### Deployment Verification

The following output verifies that both microservices are running with two healthy replicas distributed across the Kubernetes worker nodes.

![Kubernetes Application Deployment](docs/screenshots/step-06-kubernetes-deployment.png)

## STEP-07 Kubernetes Horizontal Pod Autoscaling

Horizontal Pod Autoscaling (HPA) is configured for both microservices using the Kubernetes `autoscaling/v2` API.

### HPA Configuration

- Service A: minimum 2 replicas, maximum 6 replicas
- Service B: minimum 2 replicas, maximum 6 replicas
- CPU utilization target: 70%
- Memory utilization target: 75%
- Metrics Server provides CPU and memory metrics to the HPA
- Scale-down stabilization window: 300 seconds to prevent rapid scaling fluctuations

### Autoscaling Validation

Metrics Server was configured and verified using `kubectl top`.

During load testing, Service A exceeded the 70% CPU target and the HPA increased the desired replica count up to 6.

The local kind cluster contains two worker nodes with strict required pod anti-affinity. This limits the number of Service A replicas that can remain scheduled simultaneously. The original required anti-affinity configuration was retained after testing.

### HPA Verification

The following output verifies resource metrics and Horizontal Pod Autoscaler configuration for both microservices.

![Kubernetes HPA Verification](docs/screenshots/step-07-hpa-verification.png)

## STEP-08 Kubernetes Ingress and TLS routing

- **Ingress controller**: ingress-nginx
- **Host**: devops.local
- **Paths**:
	- `/api/v1` -> `service-a:8080`
	- `/api/v2` -> `service-b:8000`
- **TLS termination**: handled at the Ingress (TLS secret `devops-local-tls`)
- **TLS secret**: `devops-local-tls` (created in `default` namespace for local testing)
- **Certificate**: self-signed for `devops.local` (for assessment use only). Do NOT commit private keys to the repository.
- **Local testing**: use `--resolve devops.local:443:127.0.0.1` with `curl`, or add `127.0.0.1 devops.local` to `/etc/hosts`.
- **HTTPS validation commands**:

```bash
# Check ingress and TLS
kubectl get ingress -A
kubectl describe ingress devops-ingress -n default

# Verify ingress controller
kubectl get pods -n ingress-nginx -o wide
kubectl get svc -n ingress-nginx -o wide

# Test Service A and B over HTTPS (use --resolve or /etc/hosts)
curl -k -i --resolve devops.local:443:127.0.0.1 https://devops.local/api/v1/health
curl -k -i --resolve devops.local:443:127.0.0.1 https://devops.local/api/v1/users
curl -k -i --resolve devops.local:443:127.0.0.1 https://devops.local/api/v2/health
curl -k -i --resolve devops.local:443:127.0.0.1 https://devops.local/api/v2/orders

# Inspect TLS certificate
openssl s_client -connect 127.0.0.1:443 -servername devops.local </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -ext subjectAltName
```

- **HTTP behavior (port 80)**: the Ingress controller redirects HTTP to HTTPS by default; expect a `308 Permanent Redirect` to the HTTPS URL.

### Ingress and TLS Verification

The following output verifies HTTPS routing through the Kubernetes Ingress controller to both microservices.

![Kubernetes Ingress and TLS Verification](docs/screenshots/step-08-ingress-tls-verification.png)

**Notes**:
- TLS private keys and certificate files created for local testing must never be committed to the repository. The Kubernetes secret `devops-local-tls` is created in-cluster from local files.
