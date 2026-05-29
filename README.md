# reto-devops — GitOps Reference Architecture (Local Kubernetes)

Arquitectura de referencia **GitOps + DevSecOps** para un entorno local de
Kubernetes (`kind`), con:

- **IaC** con Terraform que aprovisiona **ArgoCD** vía el `helm_provider`.
- Aplicación de **dos capas** (Frontend Nginx + Backend FastAPI) contenerizada
  con **Dockerfiles multi-stage**.
- Pipeline de **CI** en Azure DevOps con enfoque **Shift-Left Security**
  (secret scanning, SCA, container scanning) y publicación de imágenes
  **inmutables** a Docker Hub.
- **CD pull-based** con ArgoCD: el clúster converge automáticamente al estado
  declarado en Git.

> ⚠️ **Nota de ejecución:** este repositorio contiene todos los artefactos
> listos para reproducir. La máquina donde se generó **no tenía Docker/kind**
> instalados, por lo que el flujo end-to-end no se ejecutó aquí; sí se validó
> estáticamente (Terraform `fmt`, `helm lint`/`template`, `kubectl kustomize`,
> parseo de todos los YAML). Las instrucciones de reproducción están abajo.

---

## 1. Estrategia DevOps: separación de repositorios

Se adopta la práctica GitOps de **separar el repositorio de código del de
infraestructura**. La entrega se organiza como **dos repositorios lógicos**,
representados aquí como dos raíces autocontenidas:

| Repo lógico | Carpeta | Contenido | Responsable |
|-------------|---------|-----------|-------------|
| **App / GitOps repo** | [`app/`](./app) | Código (frontend, backend), Dockerfiles, manifiestos `/k8s` (fuente de verdad del despliegue) y el pipeline de CI (`azure-pipelines.yml`). | Equipo de desarrollo |
| **Infra repo** | [`infra/`](./infra) | Módulo Terraform que despliega ArgoCD y registra la `Application`. | Plataforma / SRE |

**¿Por qué separarlos?**

- **Ciclos de vida distintos:** la app cambia muchas veces al día; la
  plataforma (ArgoCD, clúster) cambia rara vez.
- **Permisos / blast radius:** quien hace push de código no necesita permisos
  sobre la infraestructura del clúster.
- **Evitar bucles de CI:** el job de *GitOps Update* hace auto-commit sobre los
  manifiestos; aislarlos evita disparar la infra.

> En producción, `app/` e `infra/` serían dos repos Git independientes. ArgoCD
> apuntaría al repo de app (`repoURL`) con `path: k8s`. Aquí, al vivir todo en
> un repo, `repoURL` apunta a este repo con `path: app/k8s` — configurable por
> variable de Terraform (`app_repo_url`, `app_path`).

---

## 2. Arquitectura

```
 Developer ──push──▶ Git (App repo) ──trigger──▶ Azure DevOps CI
                                                     │
        ┌────────────────────────────────────────────┤  Shift-Left
        │ 1. Secret Scan (Gitleaks)                    │
        │ 2. SCA (Trivy fs)                            │
        │ 3. Build (Dockerfiles multi-stage)           │
        │ 4. Container Scan (Trivy image)  ── gate ──▶ │
        │ 5. Push imágenes inmutables (tag = SHA) ─────┼──▶ Docker Hub
        │ 6. GitOps Update: kustomize set image        │        │
        │    + auto-commit a app/k8s                   │        │
        └────────────────────────────────────────────┘        │
                            │ (git commit)                      │
                            ▼                                    │
                       Git (manifiestos)                        │
                            │  watch (pull)                      │
                            ▼                                    │
   ┌─────────────────── kind cluster ──────────────────────┐    │
   │  ns: argocd                                            │    │
   │    ArgoCD  ──sync──▶  ns: reto-app                     │    │
   │                         ├─ Deployment frontend (Nginx) │◀───┘ pull image
   │                         │     └─ /api/* ─proxy─┐        │
   │                         └─ Deployment backend (FastAPI)│
   │                                                        │
   │  Terraform (helm_provider) instaló ArgoCD + Application│
   └────────────────────────────────────────────────────────┘
                            ▲
                            │ http://localhost:8080 (NodePort 30080)
                          Usuario
```

**Flujo de tráfico de la app:** el navegador habla solo con el **frontend**
(Nginx). Nginx sirve el HTML estático y **reverse-proxy** de `/api/*` al
`Service` `backend` dentro del clúster — mismo origen, sin CORS, el backend
nunca se expone fuera del clúster.

---

## 3. Herramientas de seguridad (Shift-Left)

| Etapa | Herramienta | Qué hace | Gate |
|-------|-------------|----------|------|
| **Secret Scanning** | **Gitleaks** | Detecta credenciales/secretos en el código e historial git. | Falla el build si encuentra secretos. |
| **SCA** | **Trivy `fs`** | Escanea dependencias (`requirements.txt`, etc.) en busca de CVEs. | Falla en `HIGH`/`CRITICAL` corregibles. |
| **Container Scanning** | **Trivy `image`** | Escanea las imágenes ya construidas (SO + libs) **antes** del push. | Falla en `HIGH`/`CRITICAL`; bloquea el push. |

Se eligió **Trivy** para SCA + contenedores por ser una sola herramienta,
rápida, sin servidor y con buena cobertura; **Gitleaks** por ser el estándar
de facto para secret scanning con escaneo de historial.

---

## 4. Mejores prácticas implementadas

- **GitOps / Single Source of Truth:** ningún `kubectl apply` manual de cargas.
  ArgoCD reconcilia desde Git (`selfHeal: true` revierte drift manual).
- **Inmutabilidad:** imágenes etiquetadas con el **commit SHA**
  (`Build.SourceVersion`), nunca `latest`. El tag se gestiona vía
  `kustomization.yaml` (`images[].newTag`).
- **Mínimo privilegio:**
  - Namespaces separados (`argocd`, `reto-app`).
  - `Namespace` con **Pod Security Standard `restricted`** forzado.
  - Contenedores: `runAsNonRoot`, `readOnlyRootFilesystem`,
    `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`,
    `seccompProfile: RuntimeDefault`.
  - Dockerfiles multi-stage sin toolchain en runtime; Nginx no-root (uid 101)
    en puerto 8080.

---

## 5. Reproducción end-to-end

### Prerrequisitos

```bash
docker --version       # Docker Engine
kind version           # >= 0.20
kubectl version --client
helm version
terraform version      # >= 1.5
```

### Paso 1 — Crear el clúster local (kind)

```bash
kind create cluster --name reto-devops --config infra/kind/kind-cluster.yaml
kubectl cluster-info --context kind-reto-devops
```

### Paso 2 — Desplegar ArgoCD + la Application (Terraform / IaC)

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # ajusta si hace falta
terraform init
terraform apply        # instala ArgoCD vía helm_provider y registra la Application
```

Acceder a la UI de ArgoCD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:80
# password admin:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
# UI: http://localhost:8081  (user: admin)
```

### Paso 3 — Pipeline de CI (Azure DevOps)

1. Crea un pipeline apuntando a `app/azure-pipelines.yml`.
2. Define variables **secretas**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.
3. Da permiso de *Contribute* al *Build Service* para el auto-commit del job
   GitOps (o usa un PAT).
4. Un push a `main` (bajo `app/`) ejecuta: secret scan → SCA → build →
   container scan → push → GitOps update (commit del nuevo tag).

### Paso 4 — CD automático (ArgoCD)

El auto-commit del paso 3 cambia `app/k8s/kustomization.yaml`. ArgoCD lo
detecta y **sincroniza solo**. Verifica:

```bash
kubectl get applications -n argocd
kubectl get pods,svc -n reto-app
```

### Paso 5 — Probar la app

```bash
curl http://localhost:8080/api/health      # {"status":"ok"}
curl http://localhost:8080/api/message
# o abre http://localhost:8080 en el navegador
```

### Limpieza

```bash
cd infra && terraform destroy
kind delete cluster --name reto-devops
```

---

## 6. Estructura del repositorio

```
.
├── app/                       # ── REPO 1: código + CI + manifiestos GitOps
│   ├── backend/               # FastAPI + Dockerfile multi-stage
│   ├── frontend/              # Nginx + Dockerfile multi-stage
│   ├── k8s/                   # Deployment/Service + kustomization (fuente de verdad CD)
│   ├── argocd/                # Application de referencia
│   ├── .azure/templates/      # plantillas reutilizables del pipeline
│   └── azure-pipelines.yml    # pipeline de CI
└── infra/                     # ── REPO 2: infraestructura (Terraform)
    ├── *.tf                   # módulo: ArgoCD vía helm_provider + Application
    ├── charts/reto-app/       # chart local que define la Application
    └── kind/kind-cluster.yaml # definición del clúster local
```

Más detalle en [`app/README.md`](./app/README.md) y
[`infra/README.md`](./infra/README.md).
