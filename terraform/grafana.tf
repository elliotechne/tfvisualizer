/*
  Root-level module instantiation for Grafana.

  This file wires the `grafana` module located in `terraform/grafana` into the root
  configuration. It uses root variables `grafana_admin_user` and
  `grafana_admin_password` which were added to `variables.tf`.

  Provide sensitive values via `terraform.tfvars` or environment variables.
*/

module "grafana" {
  source = "./grafana"

  namespace      = "grafana"
  release_name   = "grafana"
  admin_user     = var.grafana_admin_user
  admin_password = var.grafana_admin_password
  # Optionally override chart_version and service_type here
  chart_version  = "~> 8.0.0"
  service_type   = "ClusterIP"
}
