# ---- Cluster (kind) ---------------------------------------------------------
variable "manage_cluster" {
  description = "Si es true, Terraform crea/destruye el clúster kind vía null_resource + CLI."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Nombre del clúster kind. El contexto kubeconfig será kind-<cluster_name>."
  type        = string
  default     = "reto-devops"
}

# ---- Cluster connection -----------------------------------------------------
variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the local kind cluster."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context. Si se deja vacío se deriva como kind-<cluster_name>."
  type        = string
  default     = ""
}

# ---- ArgoCD install ---------------------------------------------------------
variable "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart (argoproj/argo-helm)."
  type        = string
  default     = "7.7.11"
}

# ---- Application (GitOps target) --------------------------------------------
variable "app_repo_url" {
  description = "Git repository ArgoCD watches for the workload manifests."
  type        = string
  default     = "https://github.com/svillegasc/reto-devops.git"
}

variable "app_target_revision" {
  description = "Git revision (branch/tag) ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "app_path" {
  description = "Path within the repo containing the plain k8s manifests ArgoCD applies."
  type        = string
  default     = "app/k8s"
}

variable "app_namespace" {
  description = "Destination namespace for the deployed workload."
  type        = string
  default     = "reto-app"
}
