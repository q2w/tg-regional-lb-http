/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_compute_health_check" "default" {
  name                = "${var.backend_service_name}-hc"
  check_interval_sec  = var.check_interval_sec
  timeout_sec         = var.timeout_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port = var.health_check_port
  }
}

resource "google_compute_region_backend_service" "default" {
  name          = var.backend_service_name
  region        = var.region
  protocol      = "HTTP"
  timeout_sec   = 10
  health_checks = [google_compute_health_check.default.self_link]
  backend {
    group = var.instance_group
  }
}

resource "google_compute_firewall" "default_hc" {
  count   = var.health_check != null ? length(var.firewall_networks) : 0
  project = length(var.firewall_networks) == 1 && var.firewall_projects[0] == "default" ? var.project_id : var.firewall_projects[count.index]
  name    = "${var.backend_service_name}-hc-${count.index}"
  network = var.firewall_networks[count.index]
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags             = length(var.target_tags) > 0 ? var.target_tags : null
  target_service_accounts = length(var.target_service_accounts) > 0 ? var.target_service_accounts : null


  allow {
    protocol = "tcp"
    ports    = [var.health_check_port]
  }
}

resource "google_compute_region_network_endpoint_group" "serverless_negs" {
  for_each = { for serverless_neg_backend in var.serverless_neg_backends :
  "neg-${var.backend_service_name}-${serverless_neg_backend.region}" => serverless_neg_backend }


  provider              = google-beta
  project               = var.project_id
  name                  = each.key
  network_endpoint_type = "SERVERLESS"
  region                = each.value.region

  dynamic "cloud_run" {
    for_each = each.value.type == "cloud-run" ? [1] : []
    content {
      service = each.value.service_name
    }
  }

  dynamic "cloud_function" {
    for_each = each.value.type == "cloud-function" ? [1] : []
    content {
      function = each.value.service_name
    }
  }

  dynamic "app_engine" {
    for_each = each.value.type == "app-engine" ? [1] : []
    content {
      service = each.value.service_name
      version = each.value.service_version
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
