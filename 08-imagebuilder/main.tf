provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "aib" {
  name = var.aib_rg
}

removed {
  from = azurerm_resource_group.aib

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_shared_image_gallery.aib

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_shared_image.aib

  lifecycle {
    destroy = false
  }
}

resource "azurerm_resource_group_template_deployment" "aib" {
  name                = var.image_template_name
  resource_group_name = data.azurerm_resource_group.aib.name
  deployment_mode     = "Incremental"
  parameters_content = jsonencode({
    "imageTemplateName" = {
      value = var.image_template_name
    },
    "api-version" = {
      value = "2025-10-01"
    }
    "svclocation" = {
      value = var.aib_region
    }
  })

  template_content = <<TEMPLATE
  {
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "imageTemplateName": {
        "type": "string"
      },
      "api-version": {
        "type": "string"
      },
      "svclocation": {
        "type": "string"
      }
    },
  
    "variables": {},
  
    "resources": [
      {
        "name": "[parameters('imageTemplateName')]",
        "type": "Microsoft.VirtualMachineImages/imageTemplates",
        "apiVersion": "[parameters('api-version')]",
        "location": "[parameters('svclocation')]",
        "dependsOn": [],
        "tags": {
          "imagebuilderTemplate": "AzureImageBuilderSIG",
          "userIdentity": "enabled"
        },
        "identity": {
          "type": "UserAssigned",
          "userAssignedIdentities": {
            "${var.aib_user_assigned_identity_id}": {}
          }
        },
  
        "properties": {
          "buildTimeoutInMinutes": 120,
  
          "vmProfile": {
            "vmSize": "${var.aib_vm_size}",
            "osDiskSizeGB": ${var.aib_os_disk_size_gb}%{if var.aib_subnet_id != ""},
            "vnetConfig": {
              "subnetId": "${var.aib_subnet_id}"%{if var.aib_container_instance_subnet_id != ""},
              "containerInstanceSubnetId": "${var.aib_container_instance_subnet_id}"%{endif}
            }%{endif}
          },
  
          "source": {
            "type": "PlatformImage",
            "publisher": "${var.publisher}",
            "offer": "${var.offer}",
            "sku": "${var.sku}",
            "version": "${var.source_image_version}"
          },
          "customize": [
            {
              "type": "PowerShell",
              "name": "CreateBuildPath",
              "scriptUri": "${var.optimization_script_uri}"
            },
            {
              "type": "WindowsRestart",
              "restartCheckCommand": "echo Azure-Image-Builder-Restarted-the-VM  > c:\\buildArtifacts\\azureImageBuilderRestart.txt",
              "restartTimeout": "5m"
            },
            {
              "type": "WindowsUpdate",
              "searchCriteria": "IsInstalled=0",
              "filters": ["exclude:$_.Title -like '*Preview*'", "include:$true"],
              "updateLimit": 20
            }
          ],
          "distribute": [
            {
              "type": "SharedImage",
              "galleryImageId": "${var.destination_gallery_image_id}",
              "runOutputName": "${var.run_output_name}",
              "artifactTags": {
                "source": "azureVmImageBuilder",
                "baseosimg": "windowsserver2022"
              },
              "replicationRegions": [${join(",", formatlist("\"%s\"", var.image_replication_regions))}]
            }
          ]
        }
      }
    ]
  }
TEMPLATE

}

resource "null_resource" "aib" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "az resource invoke-action --resource-group ${data.azurerm_resource_group.aib.name} --resource-type Microsoft.VirtualMachineImages/imageTemplates -n ${var.image_template_name} --action Run"
  }

  depends_on = [
    azurerm_resource_group_template_deployment.aib,
  ]
}