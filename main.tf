# Copyright © 2020 Joseph Wright <joseph@cloudboss.co>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

locals {
  ansible_config_vars = [for key, value in var.ansible_config : "${key} = ${value}"]

  ansible_config = length(var.ansible_config) == 0 ? "" : join("\n", concat(
    ["[defaults]"], local.ansible_config_vars))

  ansible_environment_vars = length(var.ansible_environment) == 0 ? [] : concat(
    [for key, value in var.ansible_environment : "${key}=${value}"], [""])

  ansible_environment = join(" ", local.ansible_environment_vars)

  python_repository = var.python_repository == "" ? "" : "-i ${var.python_repository}"

  python_requirements = join("\n",
    local.python_repository == "" ?
    var.python_requirements :
    concat([local.python_repository], var.python_requirements))

  cloud_config = templatefile("${path.module}/cloud-config.template", {
    ansible_config           = local.ansible_config
    ansible_config_esc       = jsonencode(local.ansible_config)
    ansible_directory        = var.ansible_directory
    ansible_environment      = local.ansible_environment
    ansible_requirements     = var.ansible_requirements
    ansible_requirements_esc = jsonencode(var.ansible_requirements)
    ansible_playbook_roles   = jsonencode(var.ansible_playbook_roles)
    ansible_variables        = jsonencode(var.ansible_variables)
    create_ansible_directory = var.create_ansible_directory
    python                   = var.python
    python_requirements      = var.python_requirements
    python_requirements_esc  = jsonencode(local.python_requirements)
  })
}
