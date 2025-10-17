# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 3.0"
    }
  }
}

provider "azurerm" {
    features {}
    use_cli = true 
    skip_provider_registration = true
}

# --- Resource Group ---

data "azurerm_resource_group" "rg" {
  name     = "1-c0b9602e-playground-sandbox"
}

# --- Virtual Network (VNet) ---
resource "azurerm_virtual_network" "vnet" {

    name                = "${data.azurerm_resource_group.rg.name}-network"
    address_space       = ["10.0.0.0/16"]
    location            = data.azurerm_resource_group.rg.location
    resource_group_name = data.azurerm_resource_group.rg.name
}

# --- Subnet ---
resource "azurerm_subnet" "subnet" {
  name                 = "my-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


# --- Public IP ---
resource "azurerm_public_ip" "pip" {
    name                = "my-public-ip"
    location            = data.azurerm_resource_group.rg.location
    resource_group_name = data.azurerm_resource_group.rg.name
    allocation_method   = "Dynamic"  
}

# --- Network Interface (NIC) ---
resource "azurerm_network_interface" "nic"{
    name                = "my-nic"
   
    location            = data.azurerm_resource_group.rg.location
    resource_group_name = data.azurerm_resource_group.rg.name

    ip_configuration {
        name                          = "internal"
        subnet_id                     = azurerm_subnet.subnet.id  
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.pip.id
   }
}

# --- Linux Virtual Machine (VM) ---
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "my-vm"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
      username   = "azureuser"
      public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
  }

  source_image_reference {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
  }
}

# --- Output ---
output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}