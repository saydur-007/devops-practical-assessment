STEP-10: PostgreSQL High Availability (CloudNativePG)

- Cluster name: postgres-ha
- Instances: 2
- Storage: dynamic PVCs (1Gi each, using default StorageClass)
- Managed role: `appuser` (password stored in `postgres-app-credentials` Secret in `default` namespace)
- Database: `appdb` (created via `Database` CR)

Security notes:
- The `postgres-app-credentials` Secret is created directly in-cluster and MUST NOT be committed to Git.
- Do not store plaintext passwords in this repo.

Files:
- `cluster.yaml` — CloudNativePG `Cluster` resource for postgres-ha
- `database.yaml` — CloudNativePG `Database` resource to create `appdb`

Usage:
- Create the in-cluster secret (do not commit it):
  ```bash
  PASSWORD=$(openssl rand -base64 32)
  kubectl create secret generic postgres-app-credentials \
    --from-literal=username=appuser \
    --from-literal=password="$PASSWORD" \
    --from-literal=database=appdb -n default
  unset PASSWORD
  ```
- Apply the manifests:
  ```bash
  kubectl apply -f database/postgres/cluster.yaml
  kubectl apply -f database/postgres/database.yaml
  ```

Verification results:
- Replication test table: `step10_replication_check`
- Replication result before failover: row `id=1` with note `step-10 replication before failover` was written on `postgres-ha-2` and read from replica `postgres-ha-1`.
- Controlled failover: deleted only old primary pod `postgres-ha-2`; PVCs were not deleted.
- Failover result: primary moved from `postgres-ha-2` to `postgres-ha-1`.
- Post-failover data result: row `id=1` still exists on new primary `postgres-ha-1`; `postgres-ha-2` rejoined as replica and also has the row.
- Cluster health after failover: `postgres-ha` reported `2/2` Ready and `Cluster in healthy state`.
- Replication health after failover: `postgres-ha-2` was streaming from new primary `postgres-ha-1` with `sync_state = async`.
- PVC status after failover: `postgres-ha-1` and `postgres-ha-2` PVCs remained `Bound`, `1Gi`, `RWO`, StorageClass `standard`.

NetworkPolicy verification:
- `allow-service-a-to-postgres` allows ingress to PostgreSQL TCP 5432 from pods labeled `app=service-a`.
- `allow-service-a-egress-to-postgres` allows Service A egress to kube-dns and PostgreSQL TCP 5432.
- `deny-service-b-to-postgres` isolates PostgreSQL ingress with an empty ingress rule set, so only explicit allow policies apply.
- Service A test pod result: `postgres-ha-rw:5432` open.
- Service B test pod result: TCP 5432 blocked by timeout.
- Unrelated test pod result: TCP 5432 blocked by timeout.
- CloudNativePG replication remained healthy after the NetworkPolicy checks.

Screenshot:
- Target path: `docs/screenshots/step-10-postgresql-ha-verification.png`
- Do not create a synthetic screenshot. Capture a real terminal screenshot after running the verification commands.
