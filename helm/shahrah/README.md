# Shahrah Helm Chart

This chart deploys Shahrah services/apps for staging and production.

## Workloads

- `control-plane`
- `model-discovery`
- `model-discovery-web`
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

## Container registry

- All Shahrah workloads use the Docker Hub repository `delpak/godar-ai`.
- Tags are service-qualified, for example `control-plane-v1.2.3` and `website-sha-<commit>`.
- Environment values store only the version portion; the chart prepends the workload name while rendering.
- Private pulls require a `regcred` image pull secret created with the Docker Hub username and personal access token.

## Typesense model-discovery rollout

- `model-discovery` expects these config keys in every promoted environment:
  - `TYPESENSE_HOST`
  - `TYPESENSE_PORT`
  - `TYPESENSE_PROTOCOL`
  - `TYPESENSE_COLLECTION_MODELS`
  - `TYPESENSE_READS_ENABLED`
  - `TYPESENSE_READY_STRICT`
- `TYPESENSE_API_KEY` remains a secret-backed env var from `shahrah-secret`.
- Recommended promoted behavior for `staging` and `production` is:
  - `TYPESENSE_READS_ENABLED=true`
  - `TYPESENSE_READY_STRICT=true`
- With strict readiness enabled, `model-discovery` will not report ready unless both Postgres and Typesense are reachable.
- This matches the application-level hybrid read-path where Typesense serves heavy list/search/facet flows and Postgres remains the source of truth for relational detail reads.

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
