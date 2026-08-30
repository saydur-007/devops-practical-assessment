# STEP-11: SQL Server Persistent Workload

Microsoft SQL Server runs as a single-replica StatefulSet with persistent storage and Secret-based SA credentials.

Files:
- `service.yaml` - ClusterIP Service named `mssql` on TCP/1433
- `statefulset.yaml` - StatefulSet named `mssql` with a `2Gi` `standard` PVC

Local verification status:
- Image: `mcr.microsoft.com/mssql/server:2022-latest`
- StatefulSet: `mssql` reached `1/1` Ready.
- PVC: `mssql-data-mssql-0` became `Bound`, `2Gi`, StorageClass `standard`.
- Persistence: row `id=1`, note `step-11 mssql persistence` existed before and after deleting only `mssql-0`.

Create the in-cluster Secret without committing credentials:

```bash
kubectl create secret generic sqlserver-credentials \
  --from-literal=MSSQL_SA_PASSWORD=<STRONG_SQLSERVER_SA_PASSWORD>
```

Deploy:

```bash
kubectl apply -f database/mssql/service.yaml
kubectl apply -f database/mssql/statefulset.yaml
kubectl rollout status statefulset/mssql --timeout=600s
```

Verify:

```bash
kubectl get statefulset mssql
kubectl get pods -l app=mssql -o wide
kubectl get svc mssql
kubectl get pvc
kubectl get pv
kubectl get secret sqlserver-credentials
```

Persistence test:

```bash
kubectl exec mssql-0 -- bash -lc \
  '/opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1 -U sa -P "$MSSQL_SA_PASSWORD" -C -d appdb -Q "SELECT * FROM dbo.step11_persistence_test;"'
```

Delete only the SQL Server pod, wait for the StatefulSet to recreate it, then rerun the query above.

Storage note:
- The local kind `standard` StorageClass uses `rancher.io/local-path`.
- It does not advertise `allowVolumeExpansion: true`, so PVC expansion was not tested locally.
- Production environments should use an expandable CSI-backed StorageClass.

Cleanup:

```bash
kubectl delete -f database/mssql/statefulset.yaml
kubectl delete -f database/mssql/service.yaml
kubectl delete pvc mssql-data-mssql-0
kubectl delete secret sqlserver-credentials
```
