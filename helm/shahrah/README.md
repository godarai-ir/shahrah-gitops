# Shahrah Helm Chart

This chart deploys Shahrah services/apps for staging and production.

Production rollout and operations for Google, GitHub, and Microsoft sign-in
are documented in [SOCIAL_AUTH_PRODUCTION.md](SOCIAL_AUTH_PRODUCTION.md).

## Production load-test mock provider

The in-process Silk Road mock provider must remain disabled until a dedicated
load-test tenant and model deployment have been provisioned. Production values
must use exact IDs:

```yaml
silkRoad:
  env:
    SILK_ROAD_ENABLE_MOCK_PROVIDER: "true"
    SILK_ROAD_MOCK_ALLOWED_TENANT_IDS: "<dedicated-tenant-uuid>"
    SILK_ROAD_MOCK_ALLOWED_DEPLOYMENT_IDS: "<dedicated-deployment-uuid>"
```

Never use `*` for the production tenant allowlist. The Silk Road adapter denies
requests unless both the tunnel request tenant ID and deployment ID match.
Roll out a Silk Road image containing this fail-closed enforcement before
changing the enable flag to `true`.

## Workloads

- `control-plane`
- `model-discovery`
- `model-discovery-web`
- `support-admin`
- `silk-road`
- `tenant-admin`
- `website`
- `blog`
- `docs`

## Secrets model

- Production values are configured for `secrets.create: false`.
- A pre-provisioned Kubernetes Secret named `shahrah-secret` must exist in the target namespace.
- Do not commit plaintext secret values into `values*.yaml`.
- When `postgres.enabled=true`, that Secret must also include `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`.
- When `privateFiles.enabled=true`, that Secret must include `PRIVATE_FILES_S3_ACCESS_KEY` and `PRIVATE_FILES_S3_SECRET_KEY`.
- `control-plane` reads `TYPESAFE_API_KEY` from `shahrah-secret` to authenticate `semantic_policy` guardrail calls to the TypeSafe API; without it, selected semantic guardrails fail as execution errors.

## Private files and malware scanning

- `privateFiles.enabled=true` deploys an internal MinIO StatefulSet, an idempotent bucket bootstrap Job, and a ClamAV Deployment.
- MinIO data is persistent; production uses the `longhorn-prod-r2` storage class.
- The bucket is private and shared by support-ticket attachments and bank-transfer receipt images under separate object prefixes.
- Both upload paths fail closed when storage or ClamAV is unavailable. Never enable `SUPPORT_ATTACHMENT_ALLOW_UNSCANNED_DEV` in production.
- MinIO and ClamAV container images are pinned by digest. Update the digest intentionally when promoting dependency updates.

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

- `migrate-clickhouse`, `migrate-main-db`, `model-discovery-migrate`, and `model-discovery-catalog-import` run as Argo CD `Sync` hooks.
- External datastore aliases are applied in sync wave `-10`, ClickHouse migration assets in `-7`, migration jobs run in waves `-6`, `-5`, and `-4`, then catalog import runs in wave `-3`.
- `model-discovery-catalog-import` reads the provider YAML catalog embedded at
  `/app/apps/model-discovery/providers` in the model-discovery migration image.
- The import uses `--clear-missing`, so removing a model YAML file reconciles
  that removal to the database on the next sync.
- The import also uses `--clear-missing-providers`, so removing an entire
  provider directory deletes that provider and its cascade-owned catalog data.

## Validation

```bash
helm lint helm/shahrah
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml -f helm/shahrah/values.staging.yaml
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml -f helm/shahrah/values.production.yaml
```
