# El contexto kubeconfig de kind es siempre kind-<nombre>. Si el operador no fija
# `kube_context` explícitamente, se deriva del nombre del clúster para que no haya
# que mantener el nombre en dos sitios.
locals {
  kube_context = var.kube_context != "" ? var.kube_context : "kind-${var.cluster_name}"
}

# El Helm provider habla con el clúster kind local a través del contexto kubeconfig
# que `kind create cluster` escribe (kind-<clustername>). La conexión es perezosa:
# sólo se establece al aplicar un helm_release, que depende del null_resource que
# crea el clúster, de modo que todo funciona en un único `terraform apply`.
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = local.kube_context
  }
}
