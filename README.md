# terraform-cloudinit-terrible

`terrible` is a Terraform module to configure [`cloud-init`](https://cloudinit.readthedocs.io/en/latest/) to run Ansible on first boot.

Instead of the typical Ansible model where changes are pushed to machines over ssh, this configures machines to apply Ansible roles to themselves. There is no centralized configuration management, Ansible Tower, or any server needed except for a place to host Ansible roles. The recommended method is to package the roles into versioned tarballs and store them in [Artifactory](https://jfrog.com/artifactory/), [Nexus](https://www.sonatype.com/nexus-repository-oss), or a cloud storage bucket. Git repositories can also be used.

By default, a machine configured with `terrible` will:

* Include a playbook generated from roles and variables passed to Terraform.
* Create a Python virtualenv and install Python dependencies, including Ansible, into it.
* Download and install the Ansible roles.
* Run the playbook!

The generated playbook only includes variables and applies the roles, so all tasks must come from the roles.

Keep in mind when writing roles that they run against localhost, so behavior may differ somewhat from roles which are run against remote hosts. For example, the `copy` module is unlikely to need `remote_src: true`, and features like `delegate_to: localhost` would be redundant.

## Customize Terrible

If the default behavior doesn't work for you, there are several ways to customize it.

### Change default Ansible options

If `ansible_config` is defined, the Ansible config file `/etc/ansible/ansible.cfg` will be written. Any of the "Ini Keys" defined in [Ansible Configuration Settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html) for the `default` section can be used here.

### Change behavior with environment variables

If `ansible_environment` is defined, `ansible-playbook` will run with the environment variables given. This gives you another way to set Ansible configuration options, define `https_proxy`, `AWS_DEFAULT_REGION`, or anything else that might be useful.

### Pass additional Ansible variables

Variables can be passed to roles in the definition of `ansible_roles`. If `ansible_variables` is defined, the additional variables will be written to `/etc/ansible/vars.yml` and the generated playbook will include them.

### Use Ansible from the package manager

Instead of creating a virtualenv and installing Ansible into it on boot, you can set `create_ansible_directory` to `false` and `ansible_directory` to a location such as `/usr` to use a version of Ansible that has been preinstalled into the machine image by a package manager or by some other means.

### Install Python packages from a private repository

If `python_repository` is defined, Python packages will be installed from there instead of the default public repository.

## Example

The following example shows machines in GCP being configured to use the output of `terrible` as user data. You can also use it in AWS or any cloud machines that run `cloud-init`.

```hcl
module "terrible" {
  source  = "cloudboss/terrible/cloudinit"
  version = "0.1.0"

  ansible_config = {
    library = "/etc/ansible/roles/foo-lib/library"
  }
  ansible_playbook_roles = [
    {
      role = "bockerizer"
      bockerizer = {
        version = "1.2.3"
      }
    }
  ]
  ansible_requirements = [
    {
      name = "bockerizer"
      src  = "https://artifactory.example.com/artifactory/ansible-roles/bockerizer-v1.2.3.tgz"
    },
    {
      name = "foo-lib"
      src  = "https://artifactory.example.com/artifactory/ansible-roles/foo-lib-v4.5.6.tgz"
    }
  ]
  python_requirements = [
    "ansible==2.9.10",
    "cffi==1.14.0",
    "cryptography==2.9.2",
    "Jinja2==2.11.2",
    "MarkupSafe==1.1.1",
    "pycparser==2.20",
    "PyYAML==5.3.1",
    "six==1.15.0",
  ]
}

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "3.0.0"

  metadata        = {
    # Terrible used here...
    "user-data" = module.terrible.cloud_config
  }
  project_id      = var.project_id
  region          = var.region
  subnetwork      = var.subnetwork
  service_account = var.service_account
}

module "compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "3.0.0"

  region            = var.region
  subnetwork        = var.subnetwork
  num_instances     = var.num_instances
  hostname          = "instance-simple"
  instance_template = module.instance_template.self_link
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| ansible\_config | Variables for configuring Ansible in /etc/ansible/ansible.cfg. | any | {} | no |
| ansible\_directory | This is the directory where Ansible is installed. If `create_ansible_directory` is `true`, a virtualenv will be created in this directory. The variable `python_requirements` should also be set to include ansible and other Python dependencies. If using Ansible installed by a distro package manager, you will most likely want to set this variable to `/usr` and set `create_ansible_directory` to `false`. | string | /opt/ansible | no |
| ansible\_environment | Environment variables to be defined when running `ansible-playbook`. | map(string) | {} | no |
| ansible\_playbook\_roles | The list of Ansible roles and, optionally, their variables to be included in the playbook. | any | n/a | yes |
| ansible\_requirements | A list of Ansible roles to be installed into /etc/ansible/roles by the `ansible-galaxy` command. Normally this should correspond to the roles defined in `ansible_playbook_roles`, unless roles have been installed ahead of time into the machine image, or if a role is being used to contain e.g. an Ansble module and does not run tasks. Each map in the list must be defined according to the following: https://galaxy.ansible.com/docs/using/installing.html#installing-multiple-roles-from-a-file. | list(map(string)) | [] | no |
| ansible\_variables | Ansible variables to be defined when running `ansible-playbook`. | any | {} | no |
| create\_ansible\_directory | Whether or not to create a virtualenv in which to install Ansible. This requires that `python_requirements` includes the ansible pip package and any other dependencies. | bool | true | no |
| python | The name of the python command. | string | python3 | no |
| python\_repository | A private PyPi repository for retrieving Python packages. If left blank, packages will be installed from the default public server. | string | "" | no |
| python\_requirements | Python dependencies, including Ansible, in the format expected by `pip`. It is highly recommended that you define the package versions in addition to the package names, and to include all dependencies here. The full list dependencies can be generated by creating a virtualenv, installing your dependencies into it, and then running `pip freeze`. | list(string) | [] | no |

## Outputs

| Name | Description | Type |
|------|-------------|------|
| cloud\_config | User data formatted for `cloud-init`. | string |

## Requirements

These sections describe requirements for using this module.

### Software

The following dependencies must be available:

- [Terraform][terraform] v0.12
