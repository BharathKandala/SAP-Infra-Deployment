# Ansible Deployment

## Environments
To find an environment, go into `./ansible/inventories/<environment>` and find the corresponding environment. In the `hosts` file, you can add hosts into their respective categories. This file accepts .ini style formatting.

## Hosts
All hosts are inside `./ansible/inventories/<environment>/hosts`, divided into groups.
Each entry requires an IP or hostname, in this format:

### Example
```ini
<hostname> ansible_host=<ip or fqdn>
```

```ini
heid1wwdp40 ansible_host=10.178.22.6
```

## Variables
See [Ansible Docs - Intro to Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html) for detailed information about Ansible inventories.

### Host vars
All variables are parsed by the roles and playbooks and defined in `./ansible/inventories/<environment>/host_vars/<hostname>.yml`. The `<hostname>` of the file name must match the hostname in the `./ansible/inventories/hosts` file for that environment. `host_vars` take precedence over `group_vars`.

### Group vars
All variables are parsed by the roles and playbooks and defined in `./ansible/inventories/<environment>/group_vars/<groupname>.yml`. The `<groupname>` of the file name must match the group name in the `group_vars/<groupname>.yml` file.

### Example
```ini
[<groupname>]
<hostname> ansible_host=<ip or fqdn>
```

```ini
[sap-web-dispatcher]
heid1wwdp40 ansible_host=10.178.22.6
```

## Deployment
To deploy a specific environment, there are several pipelines in Azure DevOps. The configs for these pipelines are under `./pipelines/ansible-<environment>.yml`. To run these pipelines, visit [Azure DevOps - Heineken/SapCoreAutomation/Ansible](https://dev.azure.com/heineken/SAPCoreAutomation/_build?definitionScope=%5CAnsible)

You may select a branch, playbook and whether or not to run Ansible in check mode before deploying.

### Notes
- Not all Ansible modules are compatible with diff and check modes.
- The VMs must first be deployed through Terraform, before Ansible can be deployed. Visit [Azure DevOps - Heineken/SapCoreAutomation/Terraform](https://dev.azure.com/heineken/SAPCoreAutomation/_build?definitionScope=%5CTerraform) for each environment.

## Roles
Roles are predefined Ansible modules that can be reused between installations and environments. You can specify external roles (from Git, Ansible Galaxy or another source) inside `./ansible/meta/requirements.yml` or use auto-loaded local roles inside the `./ansible/roles/` folder.

## Playbooks
Playbooks are located inside the root Ansible folder; `./ansible/`. Playbooks can reference roles to run, contain separate tasks to execute, or both. Using `pre_tasks` and `post_tasks` allows you to run code before and after any roles are executed.

The `hosts` key is a comma-separated list of groups or hosts to execute the playbook on. For example, the `sap_hana_install.yml` only targets servers in the group `sap-hana-db`:

### Example
```yaml
---
- hosts: sap-hana-db

  roles:
  - role: community.sap_install.sap_hana_install
    become: yes
```

### List of playbooks
| Playbook                 | Description                                                                                                                                                           |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| install_all.yml          | Playbook that triggers all other playbooks in the repository. This will bootstrap all of the automated SAP installations, OS hardening, partitioning, etc. in order.  |
| azure_storage_mounts.yml | Mounts Azure Storage Account File Shares on the target.                                                                                                               |
| cis_hardening.yml        | Applies CIS Level 1 Server Benchmark remediations.                                                                                                                    |
| create_partitions.yml    | Creates Volume Groups, Logical Volumes and partitions on physical/virtual disks.                                                                                      |
| os_settings.yml          | Applies generic packages, updates and settings for SLES15.                                                                                                            |
| sap_cc_install.yml       | Install SAP Cloud Connector using the `sap_cc_install` role.                                                                                                          |
| sap_hana_install.yml     | Installs SAP HANA Database using the official `community.sap_install.sap_hana_install`.                                                                               |
| sap_s4hana_install.yml   | Installs SAP S4HANA using the `sap_swpm` role.                                                                                                                        |
| sap_webdispatcher.yml    | Installs SAP Web Dispatcher using the `sap_swpm` role.                                                                                                                |