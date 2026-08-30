# STEP-13: Centralized Logging with Fluent Bit and Loki

This stack ships Kubernetes stdout/stderr logs to Loki for centralized querying.

Architecture:
- Loki runs as a lightweight single-replica Deployment with internal ClusterIP access on TCP/3100.
- Fluent Bit runs as a DaemonSet and tails `/var/log/containers/*.log` on each node.
- Fluent Bit parses CRI log records, attempts JSON parsing for application log payloads, enriches records with Kubernetes metadata, and forwards them to Loki.
- Loki storage is ephemeral for this local assessment. Production deployments should use durable object storage and retention policies.

Apply:

```bash
kubectl apply -f monitoring/logging/loki-configmap.yaml
kubectl apply -f monitoring/logging/loki-service.yaml
kubectl apply -f monitoring/logging/loki-deployment.yaml
kubectl rollout status deployment/loki --timeout=300s
kubectl apply -f monitoring/logging/fluent-bit-serviceaccount.yaml
kubectl apply -f monitoring/logging/fluent-bit-clusterrole.yaml
kubectl apply -f monitoring/logging/fluent-bit-clusterrolebinding.yaml
kubectl apply -f monitoring/logging/fluent-bit-configmap.yaml
kubectl apply -f monitoring/logging/fluent-bit-daemonset.yaml
kubectl rollout status daemonset/fluent-bit --timeout=300s
```

Generate a few service logs:

```bash
curl -k --resolve devops.local:443:127.0.0.1 https://devops.local/api/v1/health
curl -k --resolve devops.local:443:127.0.0.1 https://devops.local/api/v1/users
curl -k --resolve devops.local:443:127.0.0.1 https://devops.local/api/v1/error
curl -k --resolve devops.local:443:127.0.0.1 https://devops.local/api/v2/health
curl -k --resolve devops.local:443:127.0.0.1 https://devops.local/api/v2/orders
curl -k --resolve devops.local:443:127.0.0.1 https://devops.local/api/v2/error
```

Verify:

```bash
kubectl get deployment -l app=loki
kubectl get daemonset -l app=fluent-bit
kubectl get pods -l 'app in (loki,fluent-bit)' -o wide
kubectl logs -l app=fluent-bit --tail=100
```

Query Loki from inside the cluster:

```bash
kubectl run loki-query --rm -i --restart=Never --image=curlimages/curl:8.3.0 \
  -- sh -c 'curl -G -s "http://loki:3100/loki/api/v1/query_range" --data-urlencode "query={app=\"service-a\"} | json | line_format \"service={{.service}} request_id={{.request_id}} path={{.path}} status={{.status_code}}\"" --data-urlencode "limit=5"'
```

Observed structured application fields:
- Service A: `timestamp`, `level`, `service`, `request_id`, `method`, `path`, `status_code`, `duration_ms`, `msg`; error logs also include `message`.
- Service B: `timestamp`, `level`, `service`, `request_id`, `method`, `path`, `status_code`, `duration_ms`, `message`.
- The current sample applications do not emit `trace_id` or `caller`. Fluent Bit preserves those keys if the applications emit them later.

Troubleshooting:
- Check Loki readiness: `kubectl get deployment -l app=loki`
- Check Fluent Bit rollout: `kubectl get daemonset -l app=fluent-bit`
- Check output errors: `kubectl logs -l app=fluent-bit --tail=100`
- Confirm app logs exist at source: `kubectl logs -l app=service-a --tail=20`

Cleanup:

```bash
kubectl delete -f monitoring/logging/fluent-bit-daemonset.yaml
kubectl delete -f monitoring/logging/fluent-bit-configmap.yaml
kubectl delete -f monitoring/logging/fluent-bit-clusterrolebinding.yaml
kubectl delete -f monitoring/logging/fluent-bit-clusterrole.yaml
kubectl delete -f monitoring/logging/fluent-bit-serviceaccount.yaml
kubectl delete -f monitoring/logging/loki-deployment.yaml
kubectl delete -f monitoring/logging/loki-service.yaml
kubectl delete -f monitoring/logging/loki-configmap.yaml
```
