# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "azurerm" {
  features {
    resource_group { 
        prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  install_linux_defender = <<SCRIPT
    TOKEN=$(curl -sSL -k -H "Content-Type: application/json" -X POST -d '{"username":"${var.prisma_ak}","password":"${var.prisma_sk}"}' ${var.prisma_compute_url}/api/v1/authenticate | grep -Po '"'"token"'"\s*:\s*"\K([^"]*)')
    if sudo docker ps; then args=""; else args="--install-host"; fi
    curl -sSL -k --header "authorization: Bearer $TOKEN" -X POST ${var.prisma_compute_url}/api/v1/scripts/defender.sh | sudo bash -s -- -c "${var.prisma_console_name}" -m -u $args
  SCRIPT

  install_windows_defender = <<SCRIPT
    $Url = "${var.prisma_compute_url}"
    $Body = @{
        username = "${var.prisma_ak}"
        password = "${var.prisma_sk}"
    }
    $token = (Invoke-RestMethod -Method 'Post' -Uri $Url/api/v1/authenticate -Body ($Body | ConvertTo-Json) -ContentType 'application/json').token
    $parameters = @{ 
        Uri = "$Url/api/v1/scripts/defender.ps1"
        Method = "Post"
        Headers = @{
            "authorization" = "Bearer $token" 
        } 
        OutFile = "defender.ps1" 
    }
    $defenderType = "serverWindows"
    try {
      docker ps
      $defenderType = "dockerWindows"
    } catch {
      echo "Docker is not running"
      try {
        ctr c ls
        $defenderType = "containerdWindows"
      } catch {
        echo "Containerd is not running"
      }
    }
    Invoke-WebRequest @parameters
    .\defender.ps1 -type $defenderType -consoleCN ${var.prisma_console_name} -install -u
  SCRIPT
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "linux" {
  name                = "${var.prefix}-linux-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.prefix}-lin-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1ms"
  admin_username      = "azuser"
  network_interface_ids = [
    azurerm_network_interface.linux.id,
  ]

  admin_ssh_key {
    username   = "azuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_virtual_machine_extension" "linux" {
  name                 = "install_linux_defender"
  virtual_machine_id   = azurerm_linux_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
  protected_settings = <<SETTINGS
 {
  "script": "${base64encode(local.install_linux_defender)}"
 }
SETTINGS
}


resource "azurerm_network_interface" "windows" {
  name                = "${var.prefix}-win-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  name                = "${var.prefix}-win-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = "T3mp0ral123!!"
  network_interface_ids = [
    azurerm_network_interface.windows.id,
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_virtual_machine_extension" "windows" {
  name                 = "install_windows_defender"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  protected_settings = <<SETTINGS
 {
  "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(local.install_windows_defender)}')) | Out-File -filepath install.ps1\" && powershell -ExecutionPolicy Unrestricted -File install.ps1 && del install.ps1"
 }
SETTINGS
}