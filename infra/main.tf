# =============================================================================
# ArgoCD bootstrap (declarative, via the Helm provider).
#
#   1. helm_release.argocd      → installs ArgoCD (and its CRDs) into the
#                                 cluster from the official argo-helm chart.
#   2. helm_release.reto_app    → installs a tiny *local* chart that defines the
#                                 ArgoCD `Application` CR. It depends on (1) so
#                                 the Application CRD already exists. From there
#                                 ArgoCD is pull-based: it watches Git and syncs.
#
# This is the only thing applied to the cluster by automation; the application
# workloads themselves are NEVER applied by hand — ArgoCD reconciles them.
# =============================================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true

  # El clúster kind debe existir antes de instalar nada en él.
  depends_on = [null_resource.kind_cluster]

  # Wait until the chart's resources are ready before creating the Application.
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      # Local dev: serve the API/UI over plain HTTP so a simple port-forward
      # works without TLS redirects. Do NOT do this in production.
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]
}

resource "helm_release" "reto_app" {
  name      = "reto-app"
  chart     = "${path.module}/charts/reto-app"
  namespace = var.argocd_namespace

  # The Application CRD is installed by the argocd release above.
  depends_on = [helm_release.argocd]

  set {
    name  = "argocdNamespace"
    value = var.argocd_namespace
  }
  set {
    name  = "repoURL"
    value = var.app_repo_url
  }
  set {
    name  = "targetRevision"
    value = var.app_target_revision
  }
  set {
    name  = "path"
    value = var.app_path
  }
  set {
    name  = "destinationNamespace"
    value = var.app_namespace
  }
}
