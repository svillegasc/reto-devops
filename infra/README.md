# Infra repo — Terraform (ArgoCD vía Helm provider)

Este directorio representa el **repositorio de infraestructura**. Es un módulo
Terraform que aprovisiona **ArgoCD** de forma declarativa en el clúster local
(`kind`) usando el **`helm_provider`**, y registra la **`Application`** de
GitOps.

## Qué hace

1. `helm_release.argocd` — instala ArgoCD (y sus CRDs) desde el chart oficial
   `argoproj/argo-helm`.
2. `helm_release.reto_app` — instala un **chart local** (`charts/reto-app`) que
   define el recurso `Application` de ArgoCD. Depende del anterior (`depends_on`)
   para que el CRD ya exista.

> **¿Por qué un chart local en vez de `kubernetes_manifest`?** `kubernetes_manifest`
> valida contra el CRD en tiempo de `plan`, que aún no existe antes de instalar
> ArgoCD. Un chart de Helm renderiza/aplica sin esa validación previa y respeta
> el `depends_on`, evitando el problema de bootstrap. Además mantiene todo el
> aprovisionamiento dentro del `helm_provider`, como pide el reto.

Esto es lo **único** que la automatización aplica al clúster: las cargas de la
aplicación nunca se aplican a mano — ArgoCD las reconcilia desde Git.

## El clúster (`kind`)

El clúster se crea con el CLI de `kind` (necesita Docker) usando
`kind/kind-cluster.yaml`, que mapea el NodePort 30080 → puerto 8080 del host:

```bash
kind create cluster --name reto-devops --config kind/kind-cluster.yaml
```

> Se mantiene la creación del clúster fuera de Terraform a propósito: el reto
> acota Terraform a aprovisionar ArgoCD vía `helm_provider`. (Opcionalmente
> podría usarse el provider `tehcyx/kind`.)

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform apply
```

Salidas útiles (`terraform output`): comando de port-forward de la UI, comando
para leer el password admin y el nombre de la Application.

## Variables principales

| Variable | Default | Descripción |
|----------|---------|-------------|
| `kube_context` | `kind-reto-devops` | Contexto kubeconfig del clúster. |
| `argocd_chart_version` | `7.7.11` | Versión del chart `argo-cd`. |
| `app_repo_url` | repo de este proyecto | Repo Git que ArgoCD observa. |
| `app_path` | `app/k8s` | Ruta de los manifiestos (en layout de 2 repos sería `k8s`). |
| `app_namespace` | `reto-app` | Namespace destino de la app. |

## Acceso a ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:80
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
# http://localhost:8081  (user: admin)
```

## Limpieza

```bash
terraform destroy
kind delete cluster --name reto-devops
```
