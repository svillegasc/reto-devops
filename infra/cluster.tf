# =============================================================================
# Clúster local de Kubernetes (kind) creado DESDE Terraform.
#
# Se usa `null_resource` + `local-exec` sobre el CLI de `kind` en lugar de un
# provider de terceros (p. ej. tehcyx/kind) por dos motivos:
#
#   * Transparencia/seguridad: no se introduce un provider externo poco
#     mantenido; sólo se invocan comandos `kind` que el operador puede auditar.
#   * Ligereza: `kind` corre el clúster como contenedores en Docker (sin VM,
#     a diferencia de minikube con su driver por defecto), por lo que consume
#     muy pocos recursos.
#
# Los comandos son idempotentes: si el clúster ya existe, no se recrea.
# =============================================================================

resource "null_resource" "kind_cluster" {
  count = var.manage_cluster ? 1 : 0

  # Si cambia el nombre del clúster o el archivo de configuración, Terraform
  # vuelve a ejecutar el provisioner (que de todos modos es idempotente).
  triggers = {
    cluster_name = var.cluster_name
    config_hash  = filemd5("${path.module}/kind/kind-cluster.yaml")
  }

  # ---- Crear (sólo si no existe) --------------------------------------------
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      if kind get clusters 2>/dev/null | grep -qx "${var.cluster_name}"; then
        echo "kind: el clúster '${var.cluster_name}' ya existe — se omite la creación."
      else
        echo "kind: creando el clúster '${var.cluster_name}'..."
        kind create cluster \
          --name "${var.cluster_name}" \
          --config "${path.module}/kind/kind-cluster.yaml" \
          --wait 120s
      fi
    EOT
  }

  # ---- Eliminar (sólo si existe) --------------------------------------------
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      if kind get clusters 2>/dev/null | grep -qx "${self.triggers.cluster_name}"; then
        echo "kind: eliminando el clúster '${self.triggers.cluster_name}'..."
        kind delete cluster --name "${self.triggers.cluster_name}"
      else
        echo "kind: el clúster '${self.triggers.cluster_name}' no existe — nada que eliminar."
      fi
    EOT
  }
}