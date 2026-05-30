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

## Migrations

- `migrate-main-db` and `model-discovery-migrate` run as Helm `pre-install,pre-upgrade` hooks.
- Hook order is controlled with weights `-10` and `-9`.

## Validation

```bash
helm lint infra/helm/shahrah
helm template shahrah infra/helm/shahrah -f infra/helm/shahrah/values.yaml
helm template shahrah infra/helm/shahrah -f infra/helm/shahrah/values.yaml -f infra/helm/shahrah/values.staging.yaml
helm template shahrah infra/helm/shahrah -f infra/helm/shahrah/values.yaml -f infra/helm/shahrah/values.production.yaml
```
