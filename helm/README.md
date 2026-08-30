# Helm

This assessment uses **Kustomize overlays** as the primary GitOps delivery mechanism.

The technical requirement allows either:

- Helm Charts
- Kustomize overlays

The implemented environment configuration is located at:

- `k8s/base/`
- `k8s/overlays/staging/`
- `k8s/overlays/production/`

Kustomize was selected to keep the Kubernetes manifests simple, declarative, and easy to validate for the local assessment environment.

This directory is retained as part of the required repository structure and as a placeholder for future Helm packaging if the platform is later distributed as reusable charts.
