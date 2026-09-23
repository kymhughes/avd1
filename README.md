# AVD Terraform Pipeline Repository

This repository contains Azure DevOps pipeline-driven Terraform deployments for a private Azure Virtual Desktop (AVD) platform. The active deployment flow covered by this README is limited to these folders:

| Folder | Purpose |
|---|---|
| `02-network` | Adds AVD and private endpoint subnets, subnet NSGs, NSG rules, and route table associations to an existing VNet. |
| `03-service-objects` | Creates the service objects resource group, AVD workspace, workspace private endpoint, and AVD service-principal role assignments. |
| `04-keyvault` | Creates the Key Vault, Key Vault private endpoint, generated local admin secrets, and Key Vault access for AVD automation. |
| `05-hostpool` | Creates automated AVD host pools, session host configuration, app groups, remote apps, private endpoints, and scaling plans. |
| `06-storage` | Creates FSLogix and general-purpose storage accounts, private endpoints, and FSLogix share permissions. |
| `07-image-gallery` | Creates the Azure Compute Gallery, image definition, Azure Image Builder identity, and image-builder permissions. |
| `_common` | Shared Azure DevOps templates used by each module pipeline. |
| `_environment` | Shared environment tfvars and Azure DevOps variable templates. |

The `00`, `08`, `10`, and `11` folders are intentionally excluded from this documentation.

## High-level deployment model

Each deployable folder has its own `pipeline.yaml`. The folder pipeline is intentionally small: it defines runtime parameters and passes the folder name into the shared templates under `_common`.

```text
<module>/pipeline.yaml
  -> _common/terraform-environments.yml
       -> _common/terraform-plan-apply.yml
            -> terraform fmt
            -> terraform init
            -> terraform validate
            -> terraform plan
            -> terraform apply
```

The pipeline model is environment-aware. A single run can deploy one or more of NPD, UAT, and PRD by selecting boolean parameters at queue time. Each selected environment becomes an Azure DevOps stage with its own variable template, tfvars files, backend state key, and service connection.

## Recommended deployment order

Run the included modules in this order unless you are intentionally changing an isolated layer:

1. `02-network`
2. `03-service-objects`
3. `04-keyvault`
4. `06-storage`
5. `07-image-gallery`
6. `05-hostpool`

`05-hostpool` depends on resources from the earlier layers: workspace and service objects, Key Vault secrets, storage/network conventions, and existing subnets. `07-image-gallery` can be run before host pools when custom image plumbing is needed, but the host pool tfvars currently use marketplace images.

## Pipeline entrypoints

Each included module pipeline follows the same pattern:

```yaml
trigger: none

pool:
  name: devopspool1

parameters:
  - name: doDestroy
    type: boolean
    default: false
  - name: deployNpd
    type: boolean
    default: true
  - name: deployUat
    type: boolean
    default: false
  - name: deployPrd
    type: boolean
    default: false

stages:
  - template: ../_common/terraform-environments.yml
    parameters:
      tfFolder: <module-folder>
```

### Runtime parameters

| Parameter | Default | Effect |
|---|---:|---|
| `doDestroy` | `false` | When `true`, the plan step adds `-destroy`; the apply step then applies that destroy plan. |
| `deployNpd` | `true` | Adds an `NPD` stage using `_environment/vars-npd.yml`, `_environment/npd.tfvars`, and `<module>/npd.tfvars`. |
| `deployUat` | `false` | Adds a `UAT` stage using `_environment/vars-uat.yml`, `_environment/uat.tfvars`, and `<module>/uat.tfvars`. |
| `deployPrd` | `false` | Adds a `PRD` stage using `_environment/vars-prd.yml`, `_environment/prd.tfvars`, and `<module>/prd.tfvars`. |

All module pipelines currently use `trigger: none`, so runs are manually started. Commented branch/path trigger examples are present in the pipeline files but are not active.

## Common pipeline templates

### `_common/terraform-environments.yml`

This template expands the queue-time environment flags into concrete stages. It does not run Terraform itself; it calls `_common/terraform-plan-apply.yml` once per selected environment.

For each selected environment it sets:

| Environment | Stage | Service connection | Variable template | Shared tfvars | Module tfvars | State key format |
|---|---|---|---|---|---|---|
| NPD | `NPD` | `sp-avd-lab` | `../_environment/vars-npd.yml` | `../_environment/npd.tfvars` | `npd.tfvars` | `npd-<tfFolder>.tfstate` |
| UAT | `UAT` | `sp-avd-lab-uat` | `../_environment/vars-uat.yml` | `../_environment/uat.tfvars` | `uat.tfvars` | `uat-<tfFolder>.tfstate` |
| PRD | `PRD` | `sp-avd-lab-prd` | `../_environment/vars-prd.yml` | `../_environment/prd.tfvars` | `prd.tfvars` | `prd-<tfFolder>.tfstate` |

The environment template keeps each module pipeline consistent. If a new module follows the same folder layout, its pipeline only needs to pass a different `tfFolder` value.

### `_common/terraform-plan-apply.yml`

This template performs the Terraform work inside each environment stage.

1. **Checkout**: checks out the repo.
2. **Install Terraform**: downloads the configured Terraform version into `$(Agent.TempDirectory)/terraform`, prepends it to `PATH`, and prints the version.
3. **Agent route workaround**: adds explicit routes for `172.17.10.6/32` and `172.17.100.246/32` via the current default gateway. This exists because the self-hosted DevOps pool address range clashes with target network ranges.
4. **Format check**: runs `terraform fmt -check -recursive` in the selected module folder.
5. **Init**: writes a transient `backend.tf` containing `backend "azurerm" {}` and runs `terraform init` with backend settings from the selected environment variable template.
6. **Validate**: runs `terraform validate`.
7. **Plan**: builds a `plan_args` array, optionally adds `-destroy`, appends the shared and module tfvars files, then writes `tfplan`.
8. **Apply**: runs `terraform apply -auto-approve tfplan`.

The template exports these automation variables before init, plan, and apply:

| Variable | Purpose |
|---|---|
| `TF_IN_AUTOMATION=true` | Tells Terraform it is running non-interactively in automation. |
| `TF_INPUT=false` | Prevents prompts that would hang the pipeline. |
| `ARM_SUBSCRIPTION_ID` | Sets the deployment subscription from `$(deploymentSubscriptionId)`. |
| `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID` | Populated from the Azure DevOps service connection because `addSpnToEnvironment: true` is enabled. |
| `TF_VAR_environment` | Passes the selected environment name into Terraform. |

#### Backend behavior

The backend is not hardcoded in the Terraform modules. Instead, the pipeline writes `backend.tf` at runtime and initializes the AzureRM backend with:

```text
resource_group_name  = $(backendResourceGroupName)
storage_account_name = $(backendStorageAccountName)
container_name       = tfstate
key                  = <environment>-<module-folder>.tfstate
subscription_id      = $(stateSubscriptionId)
tenant_id            = ARM_TENANT_ID
client_id            = ARM_CLIENT_ID
use_azuread_auth     = true
```

The current environment variable templates point to:

```text
backendResourceGroupName  = rg-tfstore
backendStorageAccountName = tfstore101
```

The deployment subscription and state subscription are separated. This lets the pipeline deploy resources into the workload subscription while storing state in the state subscription.

#### Destroy behavior

When `doDestroy=true`, only the plan command changes:

```bash
terraform plan -destroy -out=tfplan ...
```

The apply step always applies the generated `tfplan`, so it will destroy only when the saved plan is a destroy plan. Treat this as a destructive production operation: review the plan output carefully before permitting it to continue.

## Environment configuration

The environment files are split into two levels:

| File type | Example | Used for |
|---|---|---|
| Azure DevOps variable template | `_environment/vars-npd.yml` | Pipeline-only values such as deployment subscription, state subscription, and backend storage account. |
| Shared Terraform tfvars | `_environment/npd.tfvars` | Common Terraform inputs such as location, tenant, hub/spoke subscription IDs, shared resource group names, VNet name, DNS zone RG, PE subnet names, and tags. |
| Module tfvars | `05-hostpool/npd.tfvars` | Module-specific inputs such as host pools, storage account names, Key Vault names, or subnet maps. |

Terraform receives both tfvars files in this order:

```text
terraform plan \
  -var-file=../_environment/<env>.tfvars \
  -var-file=<env>.tfvars
```

If the same variable appears in both files, the module-level tfvars value wins because it is loaded later.

## Module details

### `02-network`

This module works against an existing resource group and VNet. It does not create the VNet. It creates and configures subnets from the `subnets` map in `02-network/npd.tfvars`.

It can create, per subnet:

| Resource | Behavior |
|---|---|
| `azurerm_subnet.this` | Creates each subnet from `var.subnets`, including address prefixes, service endpoints, private endpoint policies, private link service policies, and optional delegations. |
| `azurerm_network_security_group.subnet` | Creates an NSG only when `subnet.nsg.create = true`. |
| `azurerm_network_security_rule.subnet` | Flattens each subnet's `security_rules` map into individual NSG rule resources. |
| `azurerm_subnet_route_table_association.this` | Associates a subnet to an existing route table when `route_table_name` is set. |
| `azurerm_subnet_network_security_group_association.this` | Associates either the newly created NSG or an existing NSG ID. |

#### Complex sections

The `locals` block builds three derived maps from `var.subnets`:

| Local | Why it exists |
|---|---|
| `subnet_route_table_names` | Filters only subnets that specify a non-empty route table name. |
| `subnet_nsg_associations` | Filters only subnets that need an NSG association, whether the NSG is newly created or existing. |
| `subnet_nsg_rules` | Flattens nested subnet rule maps into unique keys like `<subnet>.<rule>`, which Terraform can use with `for_each`. |

The NSG rule resource also contains fallback logic for singular vs plural Terraform fields. For example, if neither `source_port_range` nor `source_port_ranges` is set, it defaults to `"*"`. This keeps tfvars concise while still supporting both single-value and list-based rule definitions.

### `03-service-objects`

This module creates common service objects used by later AVD modules.

It creates:

| Resource | Purpose |
|---|---|
| Service objects resource group | Holds shared AVD service resources. |
| AVD workspace | Created through the AVM desktop virtualization workspace module with public network access disabled. |
| Workspace private endpoint | Uses the `feed` subresource and links to the hub `privatelink.wvd.microsoft.com` private DNS zone. |
| AVD service-principal role assignments | Grants the AVD service principal Reader, Power On/Off Contributor, Virtual Machine Contributor, and Network Contributor at subscription scope. |

#### Complex sections

The private endpoint subnet ID is assembled as a string from subscription, resource group, VNet, and subnet variables. This lets the module target an existing network without needing a direct `azurerm_subnet` data lookup.

The role assignments use `skip_service_principal_aad_check = true`. This is commonly needed for Microsoft service principals because the AzureAD check can fail even when the object ID is valid and Azure Resource Manager can assign the role.

### `04-keyvault`

This module creates the Key Vault used by AVD automation and session host admin credentials.

It creates:

| Resource | Purpose |
|---|---|
| Random password | Generates the local administrator password. |
| Key Vault | Created through the AVM Key Vault module with public network access disabled. |
| Key Vault private endpoint | Uses the hub `privatelink.vaultcore.azure.net` private DNS zone. |
| `time_sleep` delay | Waits before creating secrets so the private endpoint and DNS path can settle. |
| AVD Key Vault role assignment | Grants the AVD service principal `Key Vault Secrets User`. |
| Username and password secrets | Stores local admin username and generated password in Key Vault. |

#### Complex sections

Key Vault is private-only, so data-plane operations such as secret creation depend on private endpoint DNS and routing being available from the runner. The explicit `time_sleep` is a pragmatic delay to reduce failures immediately after private endpoint creation.

The secret resources use `lifecycle.ignore_changes` for `value` and `tags`. This prevents later Terraform runs from rotating or rewriting the stored credentials unintentionally. If the password must be rotated, update the Terraform intentionally rather than relying on incidental drift.

The commented CMK key block documents why key creation may need to be performed from inside the spoke network when policy forces `publicNetworkAccess = Disabled`.

### `06-storage`

This module creates private storage for FSLogix profiles plus a general-purpose storage account.

It creates:

| Resource | Purpose |
|---|---|
| FSLogix managed identity | User-assigned identity attached to the FSLogix storage account. |
| General storage managed identity | User-assigned identity attached to the general storage account. |
| FSLogix FileStorage account | Premium FileStorage account created with AzAPI. |
| FSLogix file share | SMB file share for profile containers. |
| General StorageV2 account | General-purpose storage account created with AzAPI. |
| File private endpoint | Private endpoint for the FSLogix `file` subresource. |
| Blob private endpoint | Private endpoint for the general storage `blob` subresource. |
| Storage network rules | Denies public/default network access after private endpoints exist. |
| FSLogix share role assignment | Grants the configured Entra group `Storage File Data SMB Share Contributor`. |

#### Complex sections

The storage accounts are created with `azapi_resource` instead of only `azurerm_storage_account`. This gives direct control of newer ARM properties, including identity-based Azure Files authentication and hardened storage settings.

The FSLogix identity authentication block is conditional. If `fslogix_identity_auth_directory_service` is set, the module writes `azureFilesIdentityBasedAuthentication`. If AD DS domain name and GUID are also supplied, it adds `activeDirectoryProperties`. If those inputs are null, identity auth is omitted.

The network rules depend on the private endpoints. This sequencing avoids cutting off storage access before the private path exists.

### `07-image-gallery`

This module prepares Azure Compute Gallery resources and Azure Image Builder permissions.

It creates:

| Resource | Purpose |
|---|---|
| Image gallery resource group | Holds the gallery and image builder identity. |
| Azure Compute Gallery | Shared image gallery for custom images. |
| Gallery image definition | Windows Gen2 image definition using publisher, offer, and SKU from tfvars. |
| AIB user-assigned identity | Identity used by Azure Image Builder. |
| Network Contributor assignment | Lets the AIB identity use the existing VNet. |
| Custom AIB role definition | Grants only the resource group operations needed for image build and gallery version publication. |
| Custom role assignment | Assigns the custom role to the AIB identity. |

#### Complex sections

The custom role definition is scoped to the image gallery resource group rather than the subscription. This reduces blast radius while still granting the Image Builder identity the required compute, gallery, storage, container instance, managed identity, deployment, and VNet join actions.

The module reads the existing VNet and grants the AIB identity `Network Contributor` there. This is required when image builds need to run in the private network.

### `05-hostpool`

This is the most complex included module. It creates one or more AVD host pools from the `host_pools` list in `05-hostpool/npd.tfvars`.

It creates per host pool:

| Resource | Purpose |
|---|---|
| Compute resource group | Created through `terraform_data` and `az rest`. |
| Host pool | Created with AzAPI against `Microsoft.DesktopVirtualization/hostPools@2026-04-01-preview`. |
| System-assigned host pool identity | Used for automated management actions. |
| Session host configuration | Defines VM image, size, network, credentials, tags, domain join type, security settings, and optional bootstrap script. |
| Session host management | Configured through `az rest` because it uses preview API functionality. |
| Application group | Desktop or RemoteApp group. |
| Remote apps | Created only when a host pool's app group type is `RemoteApp`. |
| AVD user role assignment | Grants the configured Entra group access to the application group. |
| VM User Login assignment | Grants the configured Entra group VM login rights on the compute resource group. |
| Workspace association | Publishes the application group into the shared workspace. |
| Host pool private endpoint | Creates the `connection` private endpoint in the configured host pool PE subnet. |
| Dynamic scaling plan | Creates a pooled autoscale plan with schedules from module defaults or per-host-pool overrides. |

#### Complex sections

The `locals` block is the main shaping layer. It merges global defaults with each object in `var.host_pools`, then builds the exact nested payloads required by the AVD preview API. This lets simple tfvars entries create full automated host pool definitions.

`default_vm_admin_credentials` builds Key Vault secret URIs when `session_host_vm_admin_credentials` is not supplied. This allows host pools to retrieve the username and password created by `04-keyvault` without copying secret values into tfvars.

`session_host_configuration` is merged in several passes:

1. Start with module defaults for disk, security, boot diagnostics, domain join, credentials, and VM location.
2. Overlay any per-host-pool `session_host_configuration` values from tfvars.
3. Force the subnet ID and merged VM tags from standard variables.
4. Add `customConfigurationScriptUrl` only when one is provided.

The compute resource group is created through `terraform_data` with a `local-exec` `az rest` call. This is unusual but allows the module to create or update the resource group using a deterministic ARM PUT payload before reading it back with `data.azurerm_resource_group.compute`.

The host pool, session host configuration, session host management, and scaling plan use `azapi_resource` or `az rest` because they depend on the `2026-04-01-preview` Desktop Virtualization API. The standard AzureRM provider may not expose these properties yet.

The host pool managed identity receives these permissions before session host management is configured:

| Scope | Role |
|---|---|
| Compute resource group | `Desktop Virtualization Virtual Machine Contributor` |
| VNet | `Network Contributor` |
| Subscription | `Reader` |
| Key Vault | `Key Vault Secrets User` |

Those assignments are dependencies for the automated session host configuration because the AVD service needs to create, update, read, and manage session hosts and retrieve local admin credentials.

The scaling plan has `lifecycle.ignore_changes = [body]`. This avoids Terraform churn when Azure normalizes or changes preview API payloads after creation, but it also means schedule/body changes may not be detected as normal drift.

## Private endpoint and DNS requirements

The included modules assume hub private DNS zones already exist and are readable from the hub provider.

| DNS zone | Used by | Module |
|---|---|---|
| `privatelink.wvd.microsoft.com` | AVD workspace feed and host pool connection private endpoints | `03-service-objects`, `05-hostpool` |
| `privatelink.vaultcore.azure.net` | Key Vault private endpoint | `04-keyvault` |
| `privatelink.file.core.windows.net` | FSLogix Azure Files private endpoint | `06-storage` |
| `privatelink.blob.core.windows.net` | General storage blob private endpoint | `06-storage` |

The modules do not create those private DNS zones. They read them with the hub provider and attach private endpoint DNS zone groups to them.

## Current NPD shape

The current NPD configuration includes:

| Area | NPD values |
|---|---|
| Location | `australiaeast` |
| Network RG | `rg-itm-network-npd` |
| VNet | `vnet-itm-vnet-npd` |
| Service objects RG | `rg-service-objects-npd` |
| Workspace | `workspace-npd` |
| Shared private endpoint subnet | `snet-general-pe` |
| AVD user group | `avd_users_cloud` |
| Key Vault | `kv-avd-itm-npd` |
| FSLogix storage | `stavditmnpd001` |
| General storage | `stgenitmnpd001` |
| Image gallery RG | `rg-imagebuilder` |
| Image gallery | `avd_image_gallery` |

Configured NPD host pools:

| Host pool | Type | RG | Session subnet | PE subnet | Notes |
|---|---|---|---|---|---|
| `pool-itm001` | Desktop | `rg-pool-itm001-npd` | `snet-itm-001` | `snet-itm-001-pe` | Uses bootstrap script URL `https://tfstore101.blob.core.windows.net/data/bootstrap-itm001.ps1`. |
| `pool-itm002` | RemoteApp | `rg-pool-itm002-npd` | `snet-itm-002` | `snet-itm-002-pe` | Publishes Server Manager from `C:\Windows\System32\ServerManager.exe`. |

## Operating the pipelines

### Normal deploy

1. Open the module pipeline, for example `05-hostpool/pipeline.yaml`.
2. Run the pipeline manually.
3. Select one or more environments with `deployNpd`, `deployUat`, or `deployPrd`.
4. Leave `doDestroy=false`.
5. Review the Terraform plan in the logs.
6. Allow the apply step to complete.

### Destroy

1. Run the same module pipeline manually.
2. Select the target environment.
3. Set `doDestroy=true`.
4. Review the destroy plan carefully.
5. Allow the apply step only if the listed deletions are expected.

Destroy is per module and per selected environment. Because each module has its own state key, destroying one module does not automatically destroy dependent modules in other state files.

### Adding a new environment

To add another environment following the current pattern:

1. Add `_environment/vars-<env>.yml` for pipeline/backend values.
2. Add `_environment/<env>.tfvars` for shared Terraform values.
3. Add `<module>/<env>.tfvars` for every module that should support the environment.
4. Extend `_common/terraform-environments.yml` with a new boolean parameter, service connection, stage block, state key prefix, variable template, and tfvars paths.
5. Add the matching boolean parameter to each module `pipeline.yaml`.

### Adding a new host pool

For the current host pool pattern:

1. Add session host and private endpoint subnets to `02-network/<env>.tfvars` if required.
2. Run `02-network` for the target environment.
3. Add another object to `05-hostpool/<env>.tfvars` under `host_pools`.
4. Set a unique `name`, `resource_group_name`, `app_group_name`, `session_host_subnet_name`, and `hostpool_private_endpoint_subnet_name`.
5. Choose `app_group_type = "Desktop"` or `"RemoteApp"`.
6. If using RemoteApp, populate `remote_apps`.
7. Run `05-hostpool` for the target environment.

## Troubleshooting notes

| Symptom | Likely cause | Action |
|---|---|---|
| `terraform fmt -check` fails | Terraform files are not formatted. | Run `terraform fmt -recursive` locally on the affected module and commit the formatting change. |
| `terraform init` cannot reach backend | Service connection, state subscription, storage account, network route, or AzureAD auth issue. | Check `_environment/vars-<env>.yml`, service connection permissions, and runner network path. |
| Private DNS zone data lookup fails | Required hub private DNS zone is missing or the hub provider cannot read it. | Confirm the zone exists in `hub_dns_zone_rg` and the service connection can read the hub subscription. |
| Key Vault secret creation fails | Runner cannot reach the private-only Key Vault data plane yet. | Confirm private endpoint DNS/routing from the runner and rerun after DNS has propagated. |
| Host pool session host automation fails | Host pool managed identity lacks required RBAC or Key Vault access. | Check role assignments in `05-hostpool` and `04-keyvault`, then rerun. |
| Scaling plan updates do not appear in Terraform diff | `azapi_resource.dynamic_scaling_plan` ignores `body` changes. | Update intentionally and consider removing or temporarily adjusting ignore behavior if drift management is required. |
| Route workaround fails in pipeline | The self-hosted runner cannot add or resolve the expected routes. | Check the runner image, permissions for `sudo ip route`, and whether the hardcoded IPs still apply. |

## Important conventions

- Keep module pipelines small and push common behavior into `_common`.
- Keep shared values in `_environment/<env>.tfvars`; keep module-specific values in `<module>/<env>.tfvars`.
- Do not store secrets in tfvars. This repository currently uses Key Vault secret URIs and generated secrets for session host local admin credentials.
- Treat `doDestroy=true` as a production-risk operation.
- Review generated plans because the apply step is non-interactive and uses `-auto-approve`.
- Keep private DNS zones in the hub and reference them from modules; the included modules do not create those zones.
- Be cautious when editing `05-hostpool`; much of it targets preview AVD API behavior through AzAPI and `az rest`.
