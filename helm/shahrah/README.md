# Shahrah Helm Chart

This chart deploys Shahrah services/apps for staging and production.

## Workloads

- `control-plane`
- `model-discovery`
- `support-admin`
- `silk-road`
- `tunnel-server`
- `tunnel-client`
- `tenant-admin`
- `website`
- `blog`
- `docs`

## Secrets model

- Production values are configured for `secrets.create: false`.
- A pre-provisioned Kubernetes Secret named `shahrah-secret` must exist in the target namespace.
- Do not commit plaintext secret values into `values*.yaml`.
- When `postgres.enabled=true`, that Secret must also include `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`.

## PostgreSQL

- The chart can deploy an in-cluster PostgreSQL instance with `postgres.enabled=true`.
- PostgreSQL is deployed as a single-replica `StatefulSet` with persistent storage.
- The chart bootstraps the `model_discovery` database via `/docker-entrypoint-initdb.d` on first initialization.

## Migrations

- `migrate-clickhouse`, `migrate-main-db`, and `model-discovery-migrate` run as Argo CD `Sync` hooks.
- External datastore aliases are applied in sync wave `-10`, ClickHouse migration assets in `-7`, then migration jobs run in waves `-6`, `-5`, and `-4`.

## Validation

```bash
helm lint helm/shahrah
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml -f helm/shahrah/values.staging.yaml
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml -f helm/shahrah/values.production.yaml
```
