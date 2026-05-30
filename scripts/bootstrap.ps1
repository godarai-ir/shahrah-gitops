$ErrorActionPreference = "Stop"

kubectl apply -f projects/shahrah-project.yaml
kubectl apply -f bootstrap/app-of-apps.yaml

kubectl -n argocd get applications.argoproj.io
