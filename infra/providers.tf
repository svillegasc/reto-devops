# The Helm provider talks to the local kind cluster via the kubeconfig context
# that `kind create cluster` writes (default: kind-<clustername>).
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
