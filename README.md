# Shahrah GitOps Repository

This repository is the single source of truth for Shahrah deployments via Argo CD.

## Layout

- `helm/shahrah`: Helm chart (staging + production values)
- `apps/`: Argo CD Application manifests
- `platform/argocd-proxy-env`: Argo CD proxy environment patch job
- `projects/`: Argo CD AppProject guardrails
- `bootstrap/`: App-of-apps root bootstrap

## Bootstrap

1. Ensure Argo CD is installed in cluster.
2. Apply project:
   - `kubectl apply -f projects/shahrah-project.yaml`
3. Apply root app:
   - `kubectl apply -f bootstrap/app-of-apps.yaml`

## Notes

- Secrets are not committed in plaintext; chart defaults to `secrets.create: false`.
- Use immutable image tags in values overrides.
- Shahrah images are pulled from `docker.io/delpak/godar-ai` with service-qualified tags such as `control-plane-v1.2.3`.
- Staging is auto-sync; production sync policy can be tightened later.
