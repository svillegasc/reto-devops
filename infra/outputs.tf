output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = helm_release.argocd.namespace
}

output "argocd_server_port_forward" {
  description = "Command to open the ArgoCD UI locally."
  value       = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8081:80"
}

output "argocd_initial_admin_password_cmd" {
  description = "Command to read the auto-generated ArgoCD admin password."
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}

output "application_name" {
  description = "Name of the bootstrapped ArgoCD Application."
  value       = "reto-app"
}
