# STEP-11: MySQL Persistent Workload

MySQL runs as a single-replica StatefulSet with persistent storage and Secret-based credentials.

Files:
- `service.yaml` - ClusterIP Service named `mysql` on TCP/3306
- `statefulset.yaml` - StatefulSet named `mysql` with a `1Gi` `standard` PVC

Create the in-cluster Secret without committing credentials:

```bash
kubectl create secret generic mysql-credentials \
  --from-literal=MYSQL_ROOT_PASSWORD=<MYSQL_ROOT_PASSWORD> \
  --from-literal=MYSQL_DATABASE=appdb \
  --from-literal=MYSQL_USER=appuser \
  --from-literal=MYSQL_PASSWORD=<MYSQL_PASSWORD>
```

Deploy:

```bash
kubectl apply -f database/mysql/service.yaml
kubectl apply -f database/mysql/statefulset.yaml
kubectl rollout status statefulset/mysql --timeout=300s
```

Verify:

```bash
kubectl get statefulset mysql
kubectl get pods -l app=mysql -o wide
kubectl get svc mysql
kubectl get pvc
kubectl get pv
kubectl get secret mysql-credentials
```

Persistence test:

```bash
MYSQL_POD=$(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$MYSQL_POD" -- sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT * FROM step11_persistence_test;"'
kubectl delete pod "$MYSQL_POD"
kubectl rollout status statefulset/mysql --timeout=300s
MYSQL_POD=$(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$MYSQL_POD" -- sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SELECT * FROM step11_persistence_test;"'
```

Verified result:
- Image: `mysql:8.4`
- StatefulSet: `mysql` reached `1/1` Ready.
- PVC: `mysql-data-mysql-0` remained `Bound`, `1Gi`, StorageClass `standard`.
- Persistence: row `id=1`, note `step-11 mysql persistence` existed before and after deleting only `mysql-0`.

Storage note:
- The local kind `standard` StorageClass uses `rancher.io/local-path`.
- It does not advertise `allowVolumeExpansion: true`, so PVC expansion was not tested locally.
- Production environments should use an expandable CSI-backed StorageClass.

Cleanup:

```bash
kubectl delete -f database/mysql/statefulset.yaml
kubectl delete -f database/mysql/service.yaml
kubectl delete pvc mysql-data-mysql-0
kubectl delete secret mysql-credentials
```
