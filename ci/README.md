# CI/CD

The CI/CD pipeline is implemented with GitHub Actions.

Workflow:

`.github/workflows/ci.yml`

Pipeline stages include:

- Kubernetes manifest validation using kubeconform
- Service A image build
- Service B image build
- Git SHA image tagging
- Trivy HIGH/CRITICAL vulnerability scanning
