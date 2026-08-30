# STEP-12: Automated Database Backups

This step runs daily database backups at 02:00 UTC and uploads compressed artifacts to local MinIO S3-compatible storage.

Architecture:
- MinIO runs in-cluster as a single-replica StatefulSet with a persistent `1Gi` PVC.
- Bucket: `db-backups`
- PostgreSQL backup: `pg_dump` from `postgres-ha-rw`, compressed as `.sql.gz`.
- MySQL backup: `mysqldump` from `mysql`, compressed as `.sql.gz`.
- SQL Server backup: native SQL Server `BACKUP DATABASE` to `.bak`, then gzip-compressed as `.bak.gz`.
- Uploads use the MinIO `mc` client with credentials from `minio-credentials`.

Create the MinIO Secret without committing credentials:

```bash
kubectl create secret generic minio-credentials \
  --from-literal=MINIO_ROOT_USER=<MINIO_ROOT_USER> \
  --from-literal=MINIO_ROOT_PASSWORD=<MINIO_ROOT_PASSWORD>
```

Deploy MinIO and create the bucket:

```bash
kubectl apply -f backup/minio-service.yaml
kubectl apply -f backup/minio-statefulset.yaml
kubectl rollout status statefulset/minio --timeout=300s
kubectl apply -f backup/minio-bucket-job.yaml
kubectl wait --for=condition=complete job/minio-create-db-backups-bucket --timeout=180s
```

Deploy CronJobs:

```bash
kubectl apply -f backup/cronjob-postgres.yaml
kubectl apply -f backup/cronjob-mysql.yaml
kubectl apply -f backup/cronjob-mssql.yaml
```

Manual backup trigger:

```bash
kubectl create job --from=cronjob/backup-postgres manual-backup-postgres
kubectl create job --from=cronjob/backup-mysql manual-backup-mysql
kubectl create job --from=cronjob/backup-mssql manual-backup-mssql
kubectl wait --for=condition=complete job/manual-backup-postgres job/manual-backup-mysql job/manual-backup-mssql --timeout=600s
```

Verification:

```bash
kubectl get cronjob
kubectl get jobs
kubectl get pods
kubectl run minio-list --rm -i --restart=Never --image=minio/mc:latest \
  --env-from=secret/minio-credentials \
  -- sh -c 'mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc ls --recursive --summarize local/db-backups'
```

Restore concepts:
- PostgreSQL: download the `.sql.gz`, decompress it, then restore with `psql` against the target database.
- MySQL: download the `.sql.gz`, decompress it, then restore with `mysql` against the target database.
- SQL Server: download the `.bak.gz`, decompress it, copy the `.bak` to SQL Server-accessible storage, then restore with `RESTORE DATABASE`.

Cleanup:

```bash
kubectl delete -f backup/cronjob-postgres.yaml
kubectl delete -f backup/cronjob-mysql.yaml
kubectl delete -f backup/cronjob-mssql.yaml
kubectl delete job minio-create-db-backups-bucket manual-backup-postgres manual-backup-mysql manual-backup-mssql --ignore-not-found
kubectl delete -f backup/minio-statefulset.yaml
kubectl delete -f backup/minio-service.yaml
kubectl delete pvc minio-data-minio-0
kubectl delete secret minio-credentials
```
