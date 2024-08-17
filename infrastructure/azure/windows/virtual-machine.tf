provider "azurerm" {
  features {}
}


variable "admin_username" {
  description = "The admin username for the Windows VM"
  type        = string
  default     = "#{project.azure.vm.username}"
}

variable "admin_password" {
  description = "The admin password for the Windows VM"
  type        = string
  sensitive   = true
  default     = "#{project.azure.vm.password}"
}

variable "vm_size" {
  description = "The size for the Windows VM"
  type        = string
  sensitive   = true
  default     = "#{project.azure.vm.size}"
}

variable "octopus_server_url" {
  description = "The URL of the Octopus Deploy server"
  type        = string
  default     = "#{project.azure.vm.octopus.url}"
}

variable "octopus_api_key" {
  description = "The URL of the Octopus Deploy server"
  type        = string
  sensitive   = true
  default     = "#{project.azure.vm.octopus.apikey}"
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
  name                = "demo-windows"
  computer_name       = "demo-windows"
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
  custom_data = base64encode(<<EOF
<powershell>  
  $ErrorActionPreference = "Stop" 
  # Download Octopus Tentacle MSI
Invoke-WebRequest -Uri "https://download.octopusdeploy.com/octopus/Octopus.Tentacle.6.0.0-x64.msi" -OutFile "C:\\Octopus.Tentacle.msi"
# Install Octopus Tentacle
Start-Process "msiexec.exe" -ArgumentList "/i C:\\Octopus.Tentacle.msi /quiet" -Wait
# Create Tentacle instance
& "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" create-instance --instance "Tentacle" --config "C:\Octopus\Tentacle.config" --console
& "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" new-certificate --instance "Tentacle" --if-blank --console
& "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" configure --instance "Tentacle" --reset-trust --console
& "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" configure --instance "Tentacle" --home "C:\Octopus" --app "C:\Octopus\Applications" --port "10933" --console
& "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" configure --instance "Tentacle" --trust "A901DF5FD0E2A300DBE457AAE4A7D16ACE609B85" --console
netsh advfirewall firewall add rule "name=Octopus Deploy Tentacle" dir=in action=allow protocol=TCP localport=10933
& "C:\\Program Files\\Octopus Deploy\\Tentacle\\Tentacle.exe" service --instance "Tentacle" --install --start --console
  EOF
  )

}

