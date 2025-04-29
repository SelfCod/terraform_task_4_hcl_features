resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = var.address_space
  location            = var.location
  resource_group_name = data.azurerm_resource_group.example.name
}

resource "azurerm_subnet" "internal" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_prefixes
}

data "azurerm_resource_group" "example" {
  name = var.resource_group_name
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_name" {
  value = azurerm_subnet.internal.name
}


# modules/network/variables.tf

variable "prefix" {
  type        = string
  description = "Prefix for network resources"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the virtual network"
}

variable "subnet_prefixes" {
  type        = list(string)
  description = "Address prefixes for the subnet"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}


# modules/security_group/main.tf

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.security_rules_list
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = lookup(security_rule.value, "source_address_prefix", "*")
      destination_address_prefix = lookup(security_rule.value, "destination_address_prefix", "*")
    }
  }
}


# modules/security_group/variables.tf

variable "prefix" {
  type        = string
  description = "Prefix for security group resources"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "security_rules_list" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = optional(string)
    destination_address_prefix = optional(string)
  }))
  description = "List of security rules"
}

# modules/virtual_machines/main.tf

resource "azurerm_network_interface" "nic" {
  for_each            = toset(var.nic_names)
  name                = each.value
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "main" {
  count                 = var.vm_count
  name                  = "${var.prefix}-vm-${count.index + 1}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic[element(keys(azurerm_network_interface.nic), count.index)].id]
  vm_size               = "Standard_DS1_v2"

  lifecycle {
    prevent_destroy = true
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk${count.index + 1}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname-${count.index + 1}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

data "azurerm_subnet" "internal" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

output "vm_names" {
  value = [for vm in azurerm_virtual_machine.main : vm.name]
}

output "vm_ids" {
  value = [for vm in azurerm_virtual_machine.main : vm.id]
}


# modules/virtual_machines/variables.tf

variable "prefix" {
  type        = string
  description = "Prefix for VM resources"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet"
}

variable "nic_names" {
  type        = list(string)
  description = "List of network interface names"
}

variable "vm_count" {
  type        = number
  description = "Number of virtual machines to create"
}