terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

# 1. Resource Group
resource "azurerm_resource_group" "jenkins_agent_rg" {
  name     = "rg-jenkins-agent-node"
  location = "East US"
}

# 2. Virtual Network
resource "azurerm_virtual_network" "agent_vnet" {
  name                = "vnet-jenkins-agent"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins_agent_rg.location
  resource_group_name = azurerm_resource_group.jenkins_agent_rg.name
}

# 3. Subnet
resource "azurerm_subnet" "agent_subnet" {
  name                 = "snet-jenkins-agent"
  resource_group_name  = azurerm_resource_group.jenkins_agent_rg.name
  virtual_network_name = azurerm_virtual_network.agent_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Public IP
resource "azurerm_public_ip" "agent_pip" {
  name                = "pip-jenkins-agent"
  location            = azurerm_resource_group.jenkins_agent_rg.location
  resource_group_name = azurerm_resource_group.jenkins_agent_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Network Security Group (Allow SSH)
resource "azurerm_network_security_group" "agent_nsg" {
  name                = "nsg-jenkins-agent"
  location            = azurerm_resource_group.jenkins_agent_rg.location
  resource_group_name = azurerm_resource_group.jenkins_agent_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 6. Network Interface (NIC)
resource "azurerm_network_interface" "agent_nic" {
  name                = "nic-jenkins-agent"
  location            = azurerm_resource_group.jenkins_agent_rg.location
  resource_group_name = azurerm_resource_group.jenkins_agent_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.agent_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "agent_nic_nsg" {
  network_interface_id      = azurerm_network_interface.agent_nic.id
  network_security_group_id = azurerm_network_security_group.agent_nsg.id
}

# 7. Dynamically Generate SSH Key Pair
resource "tls_private_key" "agent_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 8. Linux Virtual Machine (Jenkins Agent Node)
resource "azurerm_linux_virtual_machine" "jenkins_agent_vm" {
  name                = "vm-jenkins-agent"
  resource_group_name = azurerm_resource_group.jenkins_agent_rg.name
  location            = azurerm_resource_group.jenkins_agent_rg.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.agent_nic.id,
  ]

  # Cloud-init script automatically installs Java 17, Git, and Terraform on boot
  custom_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt update && sudo apt install -y openjdk-17-jre git wget gpg
              wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
              sudo apt update && sudo apt install -y terraform
              sudo useradd -m -s /bin/bash jenkins
              sudo mkdir -p /home/jenkins/agent
              sudo chown -R jenkins:jenkins /home/jenkins
              EOF
  )

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.agent_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Role      = "JenkinsAgent"
    ManagedBy = "Jenkins"
  }
}

# Outputs
output "agent_public_ip" {
  value       = azurerm_public_ip.agent_pip.ip_address
  description = "The Public IP address of the Jenkins Agent VM"
}

output "agent_private_key_pem" {
  value       = tls_private_key.agent_ssh.private_key_pem
  sensitive   = true
  description = "The generated private SSH key to connect to the agent"
}