# AVD Accelerator — Terraform Modules

Standalone, pipeline-ready Terraform modules for deploying a fully **private** Azure Virtual Desktop (AVD) environment using **Entra ID (AAD) join** — no Active Directory domain controllers required. All services are accessible exclusively through **private endpoints**. Public network access is disabled on all AVD and storage resources.

Each module maps to one pipeline stage and manages a single architectural layer. Cross-module values flow through Terraform outputs stored in local state files or pipeline variables.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       HUB Subscription (aa99492d-...)                        │
│                                                                              │
│  rg-hub-aus                          rg-privatedns                          │
│  ┌─────────────────────────────┐     ┌────────────────────────────────────┐ │
│  │  vnet-hub-aus (10.0.0.0/16) │     │  privatelink.vaultcore.azure.net   │ │
│  │  Azure Firewall (10.0.0.4)  │     │  privatelink.file.core.windows.net │ │
│  │  Azure Bastion              │     │  privatelink.wvd.microsoft.com     │ │
│  │  Hub NSG / Route Tables     │     │  privatelink-global.wvd.microsoft… │ │
│  └─────────────────────────────┘     └────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
              │ VNet Peering (hub ↔ spoke)            │ VNet Links
              ▼                                        ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                      SPOKE Subscription (05e200dc-...)                       │
│                                                                              │
│  ┌──────────────┐  ┌──────────────────────────────────────────────────────┐ │
│  │  01 · RGs    │  │  02 · Network  (rg-avd-austr-<prefix>-network)       │ │
│  │  service-obj │  │  VNet 10.100.x.0/24                                  │ │
│  │  storage     │  │  snet-avd-hp   (session hosts)                       │ │
│  │  pool-compute│  │  snet-avd-pe   (private endpoints)                   │ │
│  │  monitoring  │  │  NSG, Route Table → Firewall, VNet Peering to hub    │ │
│  └──────────────┘  └──────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌──────────────────────────┐  ┌──────────────────────────────────────────┐ │
│  │  03 · Monitoring         │  │  04 · Key Vault                          │ │
│  │  Log Analytics Workspace │  │  KV (AVM), CMK key (RSA 4096)            │ │
│  └──────────────────────────┘  │  VM admin password secret                │ │
│                                │  Private Endpoint → privatelink.vault...  │ │
│  ┌──────────────────────────┐  │  DNS VNet link in hub                    │ │
│  │  06 · FSLogix Storage    │  └──────────────────────────────────────────┘ │
│  │  Premium FileStorage     │                                              │ │
│  │  AADKERB auth            │  ┌──────────────────────────────────────────┐ │
│  │  FSLogix file share      │  │  05 · AVD Host Pool  (per-app)           │ │
│  │  Private Endpoint        │  │  Host pool (Entra SSO, public disabled)  │ │
│  │  DNS VNet link in hub    │  │  Desktop App Group + Workspace           │ │
│  └──────────────────────────┘  │  Scaling plan (AUS East timezone)        │ │
│                                │  PE: workspace feed  (privatelink.wvd…)  │ │
│  ┌──────────────────────────┐  │  PE: workspace global (privatelink-gl…)  │ │
│  │  07 · Session Hosts      │  │  PE: hostpool connection (privatelink…)  │ │
│  │  Windows 11 24H2 AVD VMs │  │  DNS VNet links in hub                   │ │
│  │  Entra ID join           │  └──────────────────────────────────────────┘ │
│  │  DSC AVD registration    │                                              │ │
│  │  FSLogix registry config │  ┌──────────────────────────────────────────┐ │
│  │  Encryption at host      │  │  08 · RBAC                               │ │
│  └──────────────────────────┘  │  VM User Login                           │ │
│                                │  FSLogix SMB Share Contributor            │ │
│                                │  Scaling Plan Power On/Off                │ │
│                                └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Per-App Design Pattern

This accelerator supports creating **multiple isolated AVD environments per application** within the same infrastructure. Foundation modules (01–04, 06) are deployed **once per environment**. Host pool and session host modules (05, 07, 08) are deployed **once per application**.

```
Foundation (deploy once)                Per-App (deploy per application)
─────────────────────────               ────────────────────────────────
01  Resource Groups                     05  Host Pool  (app_name = "finance")
02  Network                         ──► 07  Session Hosts
03  Monitoring                      ──► 08  RBAC
04  Key Vault                       │
06  FSLogix Storage                 └── 05  Host Pool  (app_name = "hr")
                                        07  Session Hosts
                                        08  RBAC
```

The `app_name` variable (e.g. `finance`, `hr`, `ops`) is embedded in all resource names created by modules 05, 07, and 08, ensuring full isolation between applications.

**Naming pattern with `app_name`:**
```
vdpool-poc1-ops-prod-australiaeast          ← host pool
vdws-poc1-ops-prod-australiaeast            ← workspace
vdag-poc1-ops-prod-australiaeast            ← app group
poc1-avd-ops-vm-1 / poc1-avd-ops-vm-2      ← session hosts
pe-avd-hp-ops-poc1                          ← host pool PE
pe-avd-ws-ops-poc1                          ← workspace feed PE
pe-avd-ws-global-ops-poc1                   ← workspace global PE
```

---

## Module Dependency Map

```
01-resource-groups ──────────────────────────────────────────────► all modules
02-network         ──────────────────────────────────────────────► 04, 05, 06, 07
03-monitoring      ──────────────────────────────────────────────► 05
04-keyvault        ──────────────────────────────────────────────► 07 (vm_password)
05-avd-hostpool    ──────────────────────────────────────────────► 07 (auto via state), 08
06-storage         ──────────────────────────────────────────────► 07 (fslogix_storage_account_name), 08
07-session-hosts   (no downstream — outputs consumed manually)
08-rbac            (no downstream dependencies)
```

---

## Module Summary Table

| # | Module | What It Creates | Key Inputs | Key Outputs |
|---|--------|----------------|------------|-------------|
| 01 | `01-resource-groups` | 4 resource groups | `prefix`, `environment`, `avdLocation` | `rg_*_name`, `rg_*_id` |
| 02 | `02-network` | VNet, 2 subnets, NSG, UDR → firewall, hub↔spoke peering | `vnet_range`, `hub_vnet`, `next_hop_ip` | `vnet_id`, `subnet_id`, `pesubnet_id` |
| 03 | `03-monitoring` | Log Analytics workspace (AVM) | `rg_monitoring_name` | `log_analytics_workspace_id` |
| 04 | `04-keyvault` | KV (AVM), CMK key, VM password, KV PE, DNS VNet link | `hub_subscription_id`, `spoke_vnet_id`, `pesubnet_id` | `vm_password_value` *(sensitive)* |
| 05 | `05-avd-hostpool` | Host pool + 3 PEs, workspace, app group, scaling plan | **`app_name`**, `pesubnet_id`, `spoke_vnet_id`, `hub_subscription_id`, `hub_dns_zone_rg` | `hostpool_name`, `registration_token`, `application_group_id` |
| 06 | `06-storage` | FSLogix Premium storage, file share, PE, DNS VNet link | `hub_subscription_id`, `spoke_vnet_id`, `pesubnet_id` | `storage_account_id`, `storage_account_name` |
| 07 | `07-session-hosts` | NICs, Win11 VMs, AAD join, DSC agent, FSLogix registry | **`app_name`**, `fslogix_storage_account_name`, `vm_password` | `vm_ids`, `vm_names`, `vm_principal_ids` |
| 08 | `08-rbac` | VM User Login, FSLogix SMB, Scaling power roles | `application_group_id`, `storage_account_id` | role assignment IDs |

> **Module 08 note:** `Desktop Virtualization User` on the app group is assigned by the AVM applicationgroup module inside module 05 — it is **not** created in module 08 to prevent 409 Conflict errors.

---

## Private Endpoint Architecture

All data plane access flows through private endpoints. No public internet exposure.

| Resource | PE Subresource | DNS Zone | Module |
|----------|---------------|----------|--------|
| Key Vault | `vault` | `privatelink.vaultcore.azure.net` | 04 |
| FSLogix Storage (Files) | `file` | `privatelink.file.core.windows.net` | 06 |
| AVD Workspace (feed) | `feed` | `privatelink.wvd.microsoft.com` | 05 |
| AVD Workspace (global) | `global` | `privatelink-global.wvd.microsoft.com` | 05 |
| AVD Host Pool (connection) | `connection` | `privatelink.wvd.microsoft.com` | 05 |

**DNS Architecture:**
- All private DNS zones live in the **hub subscription** (`rg-privatedns`) and are referenced via Terraform `data` blocks — they are **never created by application modules**
- Each module creates a **VNet link** connecting the spoke VNet to the relevant hub DNS zone (`registration_enabled = false`)
- Private endpoints register their NIC IPs in the hub DNS zones via the `private_dns_zone_group` block

**Hub DNS zones required (must pre-exist before running modules):**
```
privatelink.vaultcore.azure.net         ← for 04-keyvault
privatelink.file.core.windows.net       ← for 06-storage
privatelink.wvd.microsoft.com           ← for 05-avd-hostpool (workspace feed + hostpool connection)
privatelink-global.wvd.microsoft.com    ← for 05-avd-hostpool (workspace global)
```

Create any missing zones once:
```powershell
$sub = "aa99492d-2efe-4d6e-995c-ec734bd0cbb3"   # hub subscription
$rg  = "rg-privatedns"

az network private-dns zone create -g $rg -n "privatelink.vaultcore.azure.net"        --subscription $sub
az network private-dns zone create -g $rg -n "privatelink.file.core.windows.net"      --subscription $sub
az network private-dns zone create -g $rg -n "privatelink.wvd.microsoft.com"          --subscription $sub
az network private-dns zone create -g $rg -n "privatelink-global.wvd.microsoft.com"   --subscription $sub
```

---

## Directory Structure

```
AVD-Modules/
├── README.md
├── deploy-avd.ps1              ← interactive deployment helper script
├── knownerrors.md
├── 01-resource-groups/
│   ├── main.tf
│   ├── locals.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── dev.tfvars
│   ├── nonprod.tfvars
│   ├── prod.tfvars
│   └── terraform.tfvars.example
├── 02-network/          ← same file layout
├── 03-monitoring/       ← same file layout
├── 04-keyvault/         ← same file layout
├── 05-avd-hostpool/     ← same file layout
├── 06-storage/          ← same file layout
├── 07-session-hosts/    ← same file layout
└── 08-rbac/             ← same file layout
```

---

## Prerequisites

### 1 — Tools

| Tool | Minimum Version |
|------|----------------|
| Terraform | `>= 1.9.0` |
| Azure CLI (`az`) | latest |
| PowerShell | `>= 7.2` |

### 2 — Azure CLI login

```powershell
az login --tenant "d4b3cf5c-e7a8-4dbb-8d89-603066a7f185"
az account set --subscription "05e200dc-cec4-4234-8142-d2fe12e9d48f"   # spoke
```

### 3 — One-time feature registration (before module 07)

Module 07 enables `encryption_at_host = true` on all VMs. Register the feature first:

```powershell
az feature register --name EncryptionAtHost --namespace Microsoft.Compute

# Poll — must reach Registered (takes 10-15 min)
az feature show --name EncryptionAtHost --namespace Microsoft.Compute --query properties.state -o tsv

az provider register --namespace Microsoft.Compute
```

### 4 — AVD service principal object ID (for modules 05 and 08)

```powershell
az ad sp show --id 9cdead84-a844-4324-93f2-b2e6bb768d07 --query id -o tsv
```

Use this value for `scaling_plan_sp_id` (module 05) and `scaling_plan_service_principal_id` (module 08).

### 5 — AVD user group

Create the Entra ID security group if it does not already exist:

```powershell
az ad group create --display-name "avdusergrp" --mail-nickname "avdusergrp"
# For dev: use "avdusergrp-dev"
```

### 6 — Hub prerequisites

Before running any module, confirm the following exist in the hub subscription:
- VNet (e.g. `vnet-hub-aus`) in a resource group (e.g. `rg-hub-aus`)
- Azure Firewall with a known private IP (e.g. `10.0.0.4`)
- Azure Firewall Policy (e.g. `afwp-hub-aus`)
- All four private DNS zones in `rg-privatedns` (see section above)

### 7 — Remote state backend (recommended for pipelines)

```powershell
az group create -n rg-terraform-state -l australiaeast
az storage account create -n sttfstate<suffix> -g rg-terraform-state --sku Standard_LRS --min-tls-version TLS1_2
az storage container create -n tfstate --account-name sttfstate<suffix>
```

Then uncomment the `backend "azurerm"` block in each module's `providers.tf`.

---

## Step-by-Step Deployment

Replace `<env>` with `dev`, `nonprod`, or `prod`.

> **Important conventions:**
> - `vm_password` is always passed as a `-var` flag or pipeline secret — **never stored in tfvars**
> - Module 07 auto-reads `hostpool_name` and `registration_token` directly from `../05-avd-hostpool/terraform.tfstate` — no manual passing needed
> - Always generate a fresh plan immediately before applying — never reuse stale `.tfplan` files
> - `app_name` in modules 05 and 07 must match exactly for each application deployment

---

### Module 01 — Resource Groups

**Creates:** `rg-avd-<prefix>-<env>-<location>-service-objects`, `-storage`, `-pool-compute`, `rg-avd-<env>-<location>-monitoring`

```powershell
Set-Location ".\01-resource-groups"
terraform init
terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform output
```

**Outputs used by later modules:**

| Output | Consumed by |
|--------|-------------|
| `rg_service_objects_name` | 04, 05 |
| `rg_storage_name` | 06 |
| `rg_compute_name` | 07 |
| `rg_monitoring_name` | 03 |
| `rg_compute_id` | 08 |

---

### Module 02 — Network

**Creates:** VNet, session-host subnet (`snet-avd-hp`), PE subnet (`snet-avd-pe`, with Storage + KV service endpoints), NSG, route table (next hop → firewall), hub↔spoke VNet peering

> **Timing note:** VNet peering may fail with `ReferencedResourceNotProvisioned` if subnets are still provisioning. Re-run `terraform apply` — it is idempotent.

```powershell
Set-Location "..\02-network"
terraform init
terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform apply "tfplan"   # safe to re-run if peering 400 occurs
terraform output
```

**Outputs used by later modules:**

| Output | Consumed by |
|--------|-------------|
| `subnet_id` | 07 |
| `pesubnet_id` | 04, 05, 06 |
| `vnet_id` | 04, 05, 06 (DNS VNet links) |

---

### Module 03 — Monitoring

**Creates:** Log Analytics workspace `log-avd-<env>-<location>`

```powershell
Set-Location "..\03-monitoring"
terraform init
terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform output
```

| Output | Consumed by |
|--------|-------------|
| `log_analytics_workspace_id` | 05 (host pool / app group / workspace diagnostics) |

---

### Module 04 — Key Vault

**Creates:** Key Vault (Premium, RBAC-enabled), RSA-4096 CMK key, VM admin password secret, KV private endpoint in PE subnet, VNet link for `privatelink.vaultcore.azure.net` in hub

> **Azure Policy note:** Some environments enforce `publicNetworkAccess = Disabled` on Key Vaults via policy (common in MCAP / Azure Landing Zone tenants). This blocks the Terraform runner from creating the CMK key and VM password secret. The KV, PE, and DNS VNet link are still created successfully.
>
> Complete key and secret creation from **within the spoke VNet** (Azure Bastion / jump box / self-hosted runner):
> ```powershell
> az keyvault key create   --vault-name <kv-name> --name avd-cmk-key --kty RSA --size 4096
> az keyvault secret set   --vault-name <kv-name> --name avd-local-admin-password --value "<password>"
> ```
> The `vm_password_value` output still works — the `random_password` value is stored in TF state.

**Key tfvars values:**

| Variable | Example | Description |
|----------|---------|-------------|
| `hub_subscription_id` | `aa99492d-...` | Hub sub — for DNS zone data block |
| `hub_dns_zone_rg` | `rg-privatedns` | RG containing `privatelink.vaultcore.azure.net` |
| `rg_service_objects_name` | `rg-avd-poc1-prod-...-service-objects` | From module 01 |
| `pesubnet_id` | `.../snet-avd-pe-austr-poc1-001` | From module 02 |
| `spoke_vnet_id` | `.../vnet-avd-austr-poc1-001` | From module 02 |
| `allow_list_ip` | `["58.6.207.139"]` | Runner public IP for KV firewall |

```powershell
Set-Location "..\04-keyvault"
terraform init
terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform output -raw vm_password_value   # sensitive — copy to pipeline secret
```

| Output | Consumed by |
|--------|-------------|
| `vm_password_value` *(sensitive)* | 07 — store in `$env:TF_VAR_vm_password` |

---

### Module 05 — AVD Host Pool *(per-app)*

**Creates:**
- Host pool (Pooled, BreadthFirst, Entra SSO, `publicNetworkAccess = Disabled`)
- Desktop application group (assigns `Desktop Virtualization User` role to user group)
- Workspace (`public_network_access_enabled = false`)
- Scaling plan (AUS Eastern timezone, weekday schedule 7am–7pm)
- Diagnostics storage account (private, no public access)
- **3 private endpoints:** workspace `feed`, workspace `global`, hostpool `connection`
- **2 DNS VNet links** in hub: `privatelink.wvd.microsoft.com`, `privatelink-global.wvd.microsoft.com`
- `null_resource` to patch host pool `publicNetworkAccess = Disabled` via `az rest` (AVM v0.4.0 workaround)

> **Run once per application.** Change `app_name` for each app. The same foundation modules (01-04, 06) are shared across all apps.

**Key tfvars values:**

| Variable | Example | Description |
|----------|---------|-------------|
| **`app_name`** | `ops` | Short app identifier — max 8 lowercase alphanumeric chars |
| `prefix` | `poc1` | Environment prefix |
| `hub_subscription_id` | `aa99492d-...` | Hub sub — for DNS zone data blocks |
| `hub_dns_zone_rg` | `rg-privatedns` | Hub RG containing AVD private DNS zones |
| `rg_service_objects_name` | `rg-avd-poc1-prod-...-service-objects` | From module 01 |
| `log_analytics_workspace_id` | `.../Microsoft.OperationalInsights/workspaces/log-avd-prod-...` | From module 03 — **use proper casing** |
| `pesubnet_id` | `.../snet-avd-pe-austr-poc1-001` | From module 02 |
| `spoke_vnet_id` | `.../vnet-avd-austr-poc1-001` | From module 02 |
| `scaling_plan_sp_id` | `6774ae85-...` | AVD service principal object ID |
| `user_group_name` | `avdusergrp` | Entra ID security group for AVD users |

```powershell
Set-Location "..\05-avd-hostpool"
terraform init
terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform output
```

| Output | Consumed by |
|--------|-------------|
| `hostpool_name` | 07 (auto-read from TF state) |
| `registration_token` *(sensitive)* | 07 (auto-read from TF state) |
| `application_group_id` | 08 |

---

### Module 06 — FSLogix Storage

**Creates:** Premium FileStorage account (AADKERB, shared access keys off, private-only), FSLogix file share (`fslogix`), private endpoint in PE subnet, VNet link for `privatelink.file.core.windows.net` in hub

**Key tfvars values:**

| Variable | Example | Description |
|----------|---------|-------------|
| `hub_subscription_id` | `aa99492d-...` | Hub sub — for DNS zone data block |
| `hub_dns_zone_rg` | `rg-privatedns` | RG containing `privatelink.file.core.windows.net` |
| `rg_storage_name` | `rg-avd-poc1-prod-...-storage` | From module 01 |
| `pesubnet_id` | `.../snet-avd-pe-austr-poc1-001` | From module 02 |
| `spoke_vnet_id` | `.../vnet-avd-austr-poc1-001` | From module 02 |
| `fslogix_share_quota_gb` | `100` | FSLogix share quota in GB |

```powershell
Set-Location "..\06-storage"
terraform init
terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform output   # note storage_account_name for module 07
```

| Output | Consumed by |
|--------|-------------|
| `storage_account_name` | 07 (`fslogix_storage_account_name`) |
| `storage_account_id` | 08 |

---

### Module 07 — Session Hosts *(per-app)*

**Creates:** Network interfaces, Windows 11 24H2 AVD VMs (`encryption_at_host = true`), AADLoginForWindows extension, DSC AVD agent registration extension, **FSLogix registry configuration** via Custom Script Extension

**FSLogix configuration applied:**

| Registry Key | Value | Effect |
|---|---|---|
| `Enabled` | `1` | Activates FSLogix containers |
| `VHDLocations` | `\\<storage>.file.core.windows.net\fslogix` | Profile share UNC path |
| `DeleteLocalProfileWhenVHDShouldApply` | `1` | Removes stale local profiles |
| `FlipFlopProfileDirectoryName` | `1` | Username-first folder naming |
| `PreventLoginWithFailure` | `1` | Blocks login if mount fails |
| `PreventLoginWithTempProfile` | `1` | Blocks temp profile login |
| `IsDynamic` | `1` | VHD grows on demand |

> **`app_name` must match module 05.**
>
> VM `name` (e.g. `poc1-avd-ops-vm-1`) may exceed the 15-char Windows computer name limit. `computer_name` is set separately as `<prefix><app_name>vm<n>` (e.g. `poc1opsvm1`).
>
> Module 07 auto-reads `hostpool_name` and `registration_token` from `../05-avd-hostpool/terraform.tfstate`. Override with `hostpool_state_path` for per-app state files.

**Key tfvars values:**

| Variable | Example | Description |
|----------|---------|-------------|
| **`app_name`** | `ops` | Must match `app_name` used in module 05 |
| `rdsh_count` | `2` | Number of session host VMs |
| `vm_size` | `Standard_D2s_v5` | VM SKU |
| `rg_compute_name` | `rg-avd-poc1-prod-...-pool-compute` | From module 01 |
| `subnet_id` | `.../snet-avd-hp-austr-poc1-001` | From module 02 |
| `fslogix_storage_account_name` | `stavdpoc1t77j` | From module 06 `storage_account_name` output |
| `fslogix_share_name` | `fslogix` | Default — matches module 06 |
| `fslogix_profile_size_mb` | `30720` | Max profile VHD size (30 GB default) |

**Sensitive — pass via `-var` or env var only:**

| Variable | How to obtain |
|----------|---------------|
| `vm_password` | `terraform -chdir="..\04-keyvault" output -raw vm_password_value` |

```powershell
Set-Location "..\07-session-hosts"
terraform init

# Capture VM password from module 04 state (or use pipeline secret)
$env:TF_VAR_vm_password = (terraform -chdir="..\04-keyvault" output -raw vm_password_value)

terraform plan  -var-file="<env>.tfvars" -out="tfplan"
terraform apply "tfplan"
terraform output
```

**VM lifecycle protection — `ignore_changes` prevents accidental recreation:**
- `admin_password` — password rotations handled outside Terraform
- `name`, `computer_name`, `os_disk` — prefix/app_name changes do **not** recreate VMs
- `source_image_reference` — image updates do **not** recreate VMs

To intentionally replace a VM: `terraform taint azurerm_windows_virtual_machine.avd_vm[<index>]`

---

### Module 08 — RBAC *(per-app)*

**Creates:** 3 role assignments:
1. `Virtual Machine User Login` on the compute resource group → AVD user group
2. `Storage File Data SMB Share Contributor` on the FSLogix storage account → AVD user group
3. `Desktop Virtualization Power On Off Contributor` on the compute resource group → AVD scaling plan SP

> `Desktop Virtualization User` on the app group is managed by module 05 (AVM applicationgroup module) — it is **intentionally absent** from module 08 to avoid 409 conflicts.

**Key tfvars values:**

| Variable | Example | Description |
|----------|---------|-------------|
| `user_group_name` | `avdusergrp` | Entra ID security group for AVD users |
| `scaling_plan_service_principal_id` | `6774ae85-...` | AVD SP object ID |
| `rg_compute_id` | `.../rg-avd-poc1-prod-...-pool-compute` | From module 01 |

```powershell
Set-Location "..\08-rbac"
terraform init

$appGrpId = terraform -chdir="..\05-avd-hostpool" output -raw application_group_id
$storId   = terraform -chdir="..\06-storage"     output -raw storage_account_id

terraform plan  -var-file="<env>.tfvars" `
  -var "application_group_id=$appGrpId" `
  -var "storage_account_id=$storId" `
  -out="tfplan"

terraform apply "tfplan"
```

---

## Complete End-to-End Deploy Script

```powershell
param(
    [string]$Env     = "prod",
    [string]$AppName = "ops"   # change for each application
)

$base = Split-Path -Parent $MyInvocation.MyCommand.Path

# ── Foundation modules (run once per environment) ─────────────────────────────
foreach ($m in @("01-resource-groups","02-network","03-monitoring","04-keyvault","06-storage")) {
    Write-Host "`n=== $m ===" -ForegroundColor Cyan
    Set-Location "$base\$m"
    terraform init -upgrade
    terraform apply -var-file="$Env.tfvars" -auto-approve -input=false
}

# Capture VM password from module 04 state
$vmPass = terraform -chdir="$base\04-keyvault" output -raw vm_password_value

# ── Per-app modules (run once per application) ────────────────────────────────
Write-Host "`n=== 05-avd-hostpool ($AppName) ===" -ForegroundColor Cyan
Set-Location "$base\05-avd-hostpool"
terraform init -upgrade
terraform apply -var-file="$Env.tfvars" -auto-approve -input=false

Write-Host "`n=== 07-session-hosts ($AppName) ===" -ForegroundColor Cyan
Set-Location "$base\07-session-hosts"
terraform init -upgrade
terraform apply -var-file="$Env.tfvars" -var "vm_password=$vmPass" -auto-approve -input=false

# ── RBAC (per-app) ─────────────────────────────────────────────────────────────
Write-Host "`n=== 08-rbac ($AppName) ===" -ForegroundColor Cyan
$appGrpId = terraform -chdir="$base\05-avd-hostpool" output -raw application_group_id
$storId   = terraform -chdir="$base\06-storage"      output -raw storage_account_id
Set-Location "$base\08-rbac"
terraform init -upgrade
terraform apply -var-file="$Env.tfvars" `
  -var "application_group_id=$appGrpId" `
  -var "storage_account_id=$storId" `
  -auto-approve -input=false

Write-Host "`nDeployment complete!" -ForegroundColor Green
```

---

## Destroying All Resources

Run modules in **reverse order** (08 → 01).

> `prevent_destroy = true` is set on critical resources (all RGs, VNet, FSLogix storage, session host VMs). Temporarily disable before destroying:
>
> ```powershell
> $base = "C:\path\to\AVD-Modules"
>
> # Disable prevent_destroy
> Get-ChildItem "$base\*\main.tf" | ForEach-Object {
>     (Get-Content $_.FullName -Raw) -replace 'prevent_destroy = true','prevent_destroy = false' |
>     Set-Content $_.FullName -NoNewline
> }
>
> # ... run destroy commands below ...
>
> # Restore prevent_destroy
> Get-ChildItem "$base\*\main.tf" | ForEach-Object {
>     (Get-Content $_.FullName -Raw) -replace 'prevent_destroy = false','prevent_destroy = true' |
>     Set-Content $_.FullName -NoNewline
> }
> ```

```powershell
$Env    = "prod"
$vmPass = $env:AVD_VM_PASSWORD

foreach ($m in @("08-rbac","07-session-hosts","06-storage","05-avd-hostpool",
                  "04-keyvault","03-monitoring","02-network","01-resource-groups")) {
    Write-Host "`n=== Destroying $m ===" -ForegroundColor Yellow
    Set-Location "$base\$m"
    $extraVars = if ($m -eq "07-session-hosts") { @("-var","vm_password=$vmPass") } else { @() }
    terraform destroy -var-file="$Env.tfvars" @extraVars -auto-approve -input=false
}
```

---

## Reference Environment

| Parameter | Value |
|-----------|-------|
| `avdLocation` | `australiaeast` |
| `prefix` | `poc1` |
| `environment` | `prod` |
| `app_name` | `ops` *(example — change per application)* |
| `spoke_subscription_id` | `05e200dc-cec4-4234-8142-d2fe12e9d48f` |
| `hub_subscription_id` | `aa99492d-2efe-4d6e-995c-ec734bd0cbb3` |
| `identity_subscription_id` | `04106d48-c492-472b-b3ae-4cb333e60061` |
| `tenant_id` | `d4b3cf5c-e7a8-4dbb-8d89-603066a7f185` |
| `hub_dns_zone_rg` | `rg-privatedns` |
| Service Objects RG | `rg-avd-poc1-prod-australiaeast-service-objects` |
| Compute RG | `rg-avd-poc1-prod-australiaeast-pool-compute` |
| Storage RG | `rg-avd-poc1-prod-australiaeast-storage` |
| Monitoring RG | `rg-avd-prod-australiaeast-monitoring` |
| Network RG | `rg-avd-austr-poc1-network` |
| VNet | `vnet-avd-austr-poc1-001` (10.100.1.0/24) |
| Session Host Subnet | `snet-avd-hp-austr-poc1-001` (10.100.1.0/26) |
| PE Subnet | `snet-avd-pe-austr-poc1-001` (10.100.1.192/27) |
| Hub VNet | `vnet-hub-aus` (10.0.0.0/16) |
| Firewall private IP | `10.0.0.4` |
| Key Vault | `kv-avd-poc1-<suffix>` |
| FSLogix Storage | `stavdpoc1<suffix>` |
| Host Pool (ops) | `vdpool-poc1-ops-prod-australiaeast` |
| Workspace (ops) | `vdws-poc1-ops-prod-australiaeast` |
| Session Hosts (ops) | `poc1-avd-ops-vm-1`, `poc1-avd-ops-vm-2` |
| Computer Names (ops) | `poc1opsvm1`, `poc1opsvm2` |
| AVD SP Object ID | `6774ae85-d784-4d45-9585-876477e8f6b7` |

---

## Known Issues and Workarounds

### Key Vault — `ForbiddenByConnection` (Azure Policy enforcement)

Azure Policy in governance-managed environments enforces `publicNetworkAccess = Disabled` on Key Vaults. The Terraform runner cannot create the CMK key or VM password secret from an external IP. The KV itself, its PE, and DNS VNet link are created successfully. Complete key and secret from within the spoke VNet:

```powershell
az keyvault key create   --vault-name <kv-name> --name avd-cmk-key --kty RSA --size 4096
az keyvault secret set   --vault-name <kv-name> --name avd-local-admin-password --value "<password>"
```

### Module 02 — VNet peering `ReferencedResourceNotProvisioned`

Subnets may still be in `Updating` state when peering starts. Re-run `terraform apply` — subnets will be in `Succeeded` and peering will succeed.

### Module 05 — Log Analytics workspace ID casing

The Log Analytics workspace ID in `prod.tfvars` must use proper casing (`Microsoft.OperationalInsights`). Lowercase (`microsoft.operationalinsights`) causes the AVM diagnostic settings parser to fail:

```
✗ /providers/microsoft.operationalinsights/workspaces/log-...   (fails)
✓ /providers/Microsoft.OperationalInsights/workspaces/log-...   (correct)
```

### Module 05 — Entra SSO RDP flags

The AVM host pool module's typed `custom_rdp_properties` object silently drops unknown keys. The Entra SSO flags **must** go in the `custom_properties` free-form map:

```hcl
virtual_desktop_host_pool_custom_rdp_properties = {
  custom_properties = {
    "enablerdsaadauth"  = "i:1"
    "targetisaadjoined" = "i:1"
  }
}
```

### Module 05 — Host pool public access (AVM v0.4.0 limitation)

`avm-res-desktopvirtualization-hostpool` v0.4.0 does not expose `public_network_access`. A `null_resource` uses `az rest PATCH` to set `publicNetworkAccess = Disabled` after creation. Upgrade the AVM module to v0.5.0+ to replace this with a declarative parameter.

### Module 07 — DSC extension perpetual diff

After initial AVD agent registration, the DSC `protected_settings` show drift on every plan. `lifecycle { ignore_changes = [protected_settings] }` suppresses this.

### Module 08 — Role assignment 409 (Desktop Virtualization User)

`Desktop Virtualization User` is now assigned by module 05. If it previously existed in module 08 state, remove it:

```powershell
Set-Location ".\08-rbac"
terraform state rm azurerm_role_assignment.avd_desktop_user
```

---

## AVM Module Versions

| AVM Module | Version | Used In |
|-----------|---------|---------|
| `Azure/avm-res-keyvault-vault/azurerm` | `0.5.3` | 04-keyvault |
| `Azure/avm-res-operationalinsights-workspace/azurerm` | `0.1.3` | 03-monitoring |
| `Azure/avm-res-desktopvirtualization-hostpool/azurerm` | `0.4.0` | 05-avd-hostpool |
| `Azure/avm-res-desktopvirtualization-applicationgroup/azurerm` | `0.2.1` | 05-avd-hostpool |
| `Azure/avm-res-desktopvirtualization-workspace/azurerm` | `0.2.2` | 05-avd-hostpool |
| `Azure/avm-res-desktopvirtualization-scalingplan/azurerm` | `0.2.1` | 05-avd-hostpool |

---

## Provider Versions

| Provider | Constraint | Used In |
|----------|-----------|---------|
| `hashicorp/azurerm` | `~> 4.78.0` | all modules |
| `hashicorp/azuread` | `~> 3.9.0` | 04, 05, 08 |
| `hashicorp/http` | `~> 3.0` | 04 (runner IP auto-detection) |
| `hashicorp/random` | `~> 3.9.0` | 04, 05, 06 |
| `hashicorp/time` | `~> 0.14.0` | 07 (token rotation anchor) |
| `hashicorp/null` | `~> 3.0` | 05 (host pool public access patch) |
