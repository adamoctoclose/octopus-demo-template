provider "azurerm" {
  features {}
}


variable "admin_username" {
  description = "The admin username for the Windows VM"
  type        = string
}

variable "admin_password" {
  description = "The admin password for the Windows VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "The size for the Windows VM"
  type        = string
  sensitive   = true
}

variable "octopus_server_url" {
  description = "The URL of the Octopus Deploy server"
  type        = string
}

variable "octopus_api_key" {
  description = "The URL of the Octopus Deploy server"
  type        = string
  sensitive   = true
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "demo.octopus.windows"
  location = "UK South"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "demo-octopus-windows-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "demo-octopus-windows-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP address
resource "azurerm_public_ip" "pip" {
  name                = "demo-octopus-windows-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create a network interface
resource "azurerm_network_interface" "nic" {
  name                = "demo-octopus-windows-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Create a Windows virtual machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "demo-octopus-windows-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  custom_data = base64encode(file("install-tentacle.ps1"))
}

# Custom script extension to install Octopus Deploy Tentacle
resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = "install-tentacle"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/OctopusDeploy/OctopusTentacle/master/InstallTentacle.ps1"],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File install-tentacle.ps1"
    }
SETTINGS
}

# PowerShell script to install Octopus Deploy Tentacle
resource "local_file" "install_tentacle_script" {
  content  = <<-EOF
    # Install Octopus Deploy Tentacle
    Invoke-WebRequest -Uri "https://download.octopusdeploy.com/octopus/Octopus.Tentacle.6.0.0-x64.msi" -OutFile "C:\\Octopus.Tentacle.msi"
    Start-Process "msiexec.exe" -ArgumentList "/i C:\\Octopus.Tentacle.msi /quiet" -Wait
    & "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" create-instance --instance "Tentacle" --config "C:\\Octopus\\Tentacle\\Tentacle.config" --console
    & "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" new-certificate --instance "Tentacle" --if-blank --console
    & "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" configure --instance "Tentacle" --reset-trust --console
    & "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" register-with --instance "Tentacle" --server "${var.octopus_server_url}" --apiKey "${var.octopus_api_key}" --role "web-server" --environment "Production" --console
    & "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" service --instance "Tentacle" --install --start --console
  EOF
  filename = "install-tentacle.ps1"
}
