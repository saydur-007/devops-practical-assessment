SHELL := /bin/bash

CLUSTER_NAME := devops-assessment
KIND_CONFIG := k8s/kind-config.yaml

.PHONY: help cluster apps ingress network databases logging monitoring verify all bootstrap

help:
	@echo "Targets:"
	@echo "  make cluster     - Create kind cluster"
	@echo "  make apps        - Deploy Service A and Service B"
	@echo "  make ingress     - Deploy ingress resources"
	@echo "  make network     - Apply NetworkPolicies"
	@echo "  make databases   - Apply database manifests"
	@echo "  make logging     - Deploy Fluent Bit + Loki"
	@echo "  make monitoring  - Deploy Prometheus + Alertmanager"
	@echo "  make verify      - Show deployment health"
	@echo "  make all         - Provision and deploy stack"
	@echo "  make bootstrap   - Provision and deploy the stack"

cluster:
	@if kind get clusters | grep -qx "$(CLUSTER_NAME)"; then \
		echo "Kind cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG); \
	fi

apps:
	kubectl apply -k k8s/base/service-a
	kubectl apply -k k8s/base/service-b

ingress:
	kubectl apply -k k8s/base/ingress

network:
	kubectl apply -f k8s/base/network-policies/

databases:
	kubectl apply -f database/postgres/cluster.yaml
	kubectl apply -f database/postgres/database.yaml
	kubectl apply -f database/mysql/service.yaml
	kubectl apply -f database/mysql/statefulset.yaml
	kubectl apply -f database/mssql/service.yaml
	kubectl apply -f database/mssql/statefulset.yaml

logging:
	kubectl apply -f monitoring/logging/

monitoring:
	kubectl apply -f monitoring/prometheus/kube-state-metrics.yaml
	kubectl apply -f monitoring/prometheus/alert-rules.yaml
	kubectl apply -f monitoring/prometheus/alertmanager.yaml
	kubectl apply -f monitoring/prometheus/prometheus-k8s.yaml

verify:
	@echo "=== NODES ==="
	kubectl get nodes
	@echo
	@echo "=== APPLICATIONS ==="
	kubectl get deployments
	@echo
	@echo "=== STATEFUL WORKLOADS ==="
	kubectl get statefulset
	@echo
	@echo "=== INGRESS ==="
	kubectl get ingress
	@echo
	@echo "=== LOGGING / MONITORING ==="
	kubectl get deployment prometheus alertmanager kube-state-metrics loki || true
	kubectl get daemonset fluent-bit || true

all: cluster apps ingress network databases logging monitoring verify

.PHONY: bootstrap
bootstrap: all
