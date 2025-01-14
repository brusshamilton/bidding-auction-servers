/**
 * Copyright 2023 Google LLC
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



output "frontend_instance_groups" {
  value = toset([for manager in google_compute_region_instance_group_manager.frontends : manager.instance_group])
}

output "backend_instance_groups" {
  value = toset([for manager in google_compute_region_instance_group_manager.backends : manager.instance_group])
}

output "collector_instance_groups" {
  value = toset([for manager in google_compute_region_instance_group_manager.collector : manager.instance_group])
}
