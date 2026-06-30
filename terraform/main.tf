terraform {
  required_version = ">= 1.6.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "openstack" {
  cloud = "openstack"
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "openstack_images_image_v2" "ubuntu" {
  count       = var.use_mock_provider ? 0 : 1
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "selected" {
  count = var.use_mock_provider ? 0 : 1
  name  = var.flavor_name
}

data "openstack_networking_network_v2" "external" {
  count    = var.use_mock_provider ? 0 : 1
  name     = var.external_network_name
  external = true
}

# ==============================================================================
# CREDENTIALS — je ein Passwort pro Student (VM-Login + MySQL)
# ==============================================================================

resource "random_password" "student_passwords" {
  for_each         = toset(var.student_emails)
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "mysql_passwords" {
  for_each         = toset(var.student_emails)
  length           = 16
  special          = true
  override_special = "_%@"
}

# ==============================================================================
# SSH KEY — ein gemeinsamer Key für alle Student-VMs
# ==============================================================================

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "keypair" {
  count      = var.use_mock_provider ? 0 : 1
  name       = "wordpress-keypair-${var.deployment_id}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# ==============================================================================
# SECURITY GROUP — eine gemeinsame Security Group für alle Student-VMs
# ==============================================================================

resource "openstack_networking_secgroup_v2" "wordpress_access" {
  count       = var.use_mock_provider ? 0 : 1
  name        = "wordpress-access-${var.deployment_id}"
  description = "WordPress + MySQL: SSH (22) + HTTP (80)"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_ingress" {
  count             = var.use_mock_provider ? 0 : 1
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.wordpress_access[0].id
}

resource "openstack_networking_secgroup_rule_v2" "http_ingress" {
  count             = var.use_mock_provider ? 0 : 1
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.wordpress_access[0].id
}

# ==============================================================================
# FLOATING IPs — eine pro Student-VM
# ==============================================================================

resource "openstack_networking_floatingip_v2" "student_fip" {
  for_each = var.use_mock_provider ? toset([]) : toset(var.student_emails)
  pool     = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "student_fip_assoc" {
  for_each    = var.use_mock_provider ? toset([]) : toset(var.student_emails)
  floating_ip = openstack_networking_floatingip_v2.student_fip[each.key].address
  instance_id = openstack_compute_instance_v2.student_vm[each.key].id
}

# ==============================================================================
# VMs — eine pro Student
# ==============================================================================

resource "openstack_compute_instance_v2" "student_vm" {
  for_each = var.use_mock_provider ? toset([]) : toset(var.student_emails)

  name        = "wordpress-${replace(replace(lower(each.key), "@", "-"), ".", "-")}-${var.deployment_id}"
  image_id    = data.openstack_images_image_v2.ubuntu[0].id
  flavor_id   = data.openstack_compute_flavor_v2.selected[0].id
  key_pair    = openstack_compute_keypair_v2.keypair[0].name
  security_groups = [openstack_networking_secgroup_v2.wordpress_access[0].name]

  network {
    name = var.network_name
  }

  # Floating IP muss vor der VM allokiert sein
  depends_on = [openstack_networking_floatingip_v2.student_fip]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    floating_ip        = openstack_networking_floatingip_v2.student_fip[each.key].address
    student_username   = replace(replace(lower(each.key), "@", "_"), ".", "_")
    student_email      = each.key
    student_password   = random_password.student_passwords[each.key].result
    mysql_password     = random_password.mysql_passwords[each.key].result
    wordpress_version  = var.wordpress_version
    site_title         = var.site_title
  })
}

# ==============================================================================
# MOCK RESOURCES (für use_mock_provider = true)
# ==============================================================================

resource "null_resource" "mock_student_vms" {
  for_each = var.use_mock_provider ? toset(var.student_emails) : toset([])
  triggers = {
    deployment_id = var.deployment_id
    email         = each.key
  }
}
