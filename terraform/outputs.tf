# ==============================================================================
# SYSTEM OUTPUTS (MANDATORY)
# ==============================================================================

output "instance_id" {
  description = "MANDATORY: ID der ersten Student-VM für das Backend-Management"
  value       = var.use_mock_provider ? "mock-instance-${var.deployment_id}" : values(openstack_compute_instance_v2.student_vm)[0].id
}

output "app_name" {
  description = "MANDATORY: Name der Anwendung für das Backend-Management"
  value       = var.app_name
}

# ==============================================================================
# USER OUTPUTS
# ==============================================================================

output "student_credentials" {
  description = "Zugangsdaten aller Studierenden (WordPress + SSH)"
  sensitive   = true
  value = {
    for email in var.student_emails : email => {
      username      = replace(replace(lower(email), "@", "_"), ".", "_")
      email         = email
      password      = random_password.student_passwords[email].result
      mysql_password = random_password.mysql_passwords[email].result
      wordpress_url = var.use_mock_provider ? "http://mock-ip" : "http://${openstack_networking_floatingip_v2.student_fip[email].address}"
      ssh_command   = var.use_mock_provider ? "ssh ubuntu@mock-ip" : "ssh -i <private_key> ubuntu@${openstack_networking_floatingip_v2.student_fip[email].address}"
    }
  }
}

output "ssh_private_key" {
  description = "SSH Private Key für den VM-Zugang (gilt für alle Student-VMs)"
  sensitive   = true
  value       = tls_private_key.ssh_key.private_key_openssh
}
