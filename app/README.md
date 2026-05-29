# App repo — código, contenedores, CI y manifiestos GitOps

Este directorio representa el **repositorio de la aplicación** (código + CI +
manifiestos de despliegue). Es la **fuente de verdad** que ArgoCD observa.

## Componentes

| Capa | Tecnología | Puerto | Imagen |
|------|------------|--------|--------|
| Frontend | Nginx (no-root, uid 101) sirve HTML estático y hace reverse-proxy de `/api/*` | 8080 | `svillegasc/reto-frontend` |
| Backend | FastAPI + Uvicorn (no-root, uid 10001) | 8000 | `svillegasc/reto-backend` |

### Endpoints del backend

- `GET /api/health` — liveness/readiness (`{"status":"ok"}`)
- `GET /api/info` — metadatos de build/runtime (versión, git_sha, hostname)
- `GET /api/message` — endpoint de negocio que renderiza el frontend
- `GET /api/docs` — Swagger UI

## Dockerfiles multi-stage

Ambos usan dos etapas para mantener imágenes pequeñas y sin herramientas de
build en runtime:

- **Backend:** etapa `builder` instala dependencias en un virtualenv; la etapa
  `runtime` (python:3.12-slim) copia solo el venv + código y corre como uid
  10001. Recibe `GIT_SHA`/`APP_VERSION` por `--build-arg`.
- **Frontend:** etapa `builder` (alpine) pre-comprime assets con gzip; la etapa
  `runtime` usa `nginx-unprivileged` (no-root, 8080) y copia solo los assets.

Build local (opcional):

```bash
docker build -t svillegasc/reto-backend:dev  --build-arg GIT_SHA=$(git rev-parse HEAD) backend
docker build -t svillegasc/reto-frontend:dev frontend
```

## Manifiestos `/k8s` (kustomize)

`kustomization.yaml` agrupa namespace + Deployments + Services y, sobre todo,
gestiona los **tags de imagen** en el bloque `images:`. Render:

```bash
kubectl kustomize k8s
```

El job *GitOps Update* del pipeline ejecuta:

```bash
kustomize edit set image \
  svillegasc/reto-backend=svillegasc/reto-backend:<SHA> \
  svillegasc/reto-frontend=svillegasc/reto-frontend:<SHA>
```

y hace auto-commit. ArgoCD detecta el cambio y sincroniza (pull-based).

## Pipeline de CI (`azure-pipelines.yml`)

Stages en orden (Shift-Left): **SecretScan** (Gitleaks) → **SCA** (Trivy fs) →
**BuildAndScan** (build multi-stage + Trivy image, gate) → **Push** (Docker Hub,
tag = commit SHA) → **GitOpsUpdate** (bump tag + auto-commit).

**Variables secretas requeridas en Azure DevOps:** `DOCKERHUB_USERNAME`,
`DOCKERHUB_TOKEN`. El job GitOps necesita permiso de *Contribute* del Build
Service (o un PAT) para hacer push del commit.

## Seguridad de los workloads

Definida en los Deployments: `runAsNonRoot`, `readOnlyRootFilesystem: true`
(con `emptyDir` para `/tmp` y caché de Nginx), `allowPrivilegeEscalation:
false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`. El
namespace `reto-app` fuerza el Pod Security Standard **restricted**.
