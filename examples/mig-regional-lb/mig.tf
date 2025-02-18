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

data "template_file" "group-startup-script" {
  template = file(format("%s/gceme.sh.tpl", path.module))
  vars = {
    PROXY_PATH = ""
  }
}

module "mig_template" {
  source     = "terraform-google-modules/vm/google//modules/instance_template"
  version    = "~> 12.0"
  network    = google_compute_network.default.self_link
  subnetwork = google_compute_subnetwork.default.self_link
  service_account = {
    email  = ""
    scopes = ["cloud-platform"]
  }
  name_prefix          = "test-regional-lb-mig"
  startup_script       = data.template_file.group-startup-script.rendered
  source_image_family  = "ubuntu-2004-lts"
  source_image_project = "ubuntu-os-cloud"
  tags = [
    "test-regional-lb-mig",
  ]
}

module "mig" {
  hostname          = "test-regional-lb-mig"
  source            = "terraform-google-modules/vm/google//modules/mig"
  version           = "~> 12.0"
  instance_template = module.mig_template.self_link
  region            = var.region
  target_size       = 3
  named_ports = [{
    name = "http",
    port = 80
  }]
}
