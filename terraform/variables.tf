# ==============================================================================
# SYSTEM VARIABLES (DO NOT TOUCH)
# Diese Variablen werden vom CloudStore Backend injiziert.
# ==============================================================================

variable "deployment_id" {
  description = "Eindeutige ID des Deployments (vom CloudStore Backend gesetzt)"
  type        = string
  validation {
    condition     = length(var.deployment_id) > 0
    error_message = "deployment_id darf nicht leer sein."
  }
}

variable "use_mock_provider" {
  description = "Falls true: kein echter OpenStack-Aufruf (für lokale Tests)"
  type        = bool
  default     = false
}

# ==============================================================================
# APP PARAMETERS
# ==============================================================================

variable "app_name" {
  type        = string
  description = "Name der WordPress-Instanz"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.app_name))
    error_message = "app_name: Nur Kleinbuchstaben, Zahlen und Bindestriche erlaubt (3-20 Zeichen)."
  }
}

variable "admin_email" {
  type        = string
  description = "E-Mail des Dozenten (erhält alle Credentials)"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.admin_email))
    error_message = "admin_email: Muss eine gültige E-Mail-Adresse sein."
  }
}

variable "student_emails" {
  type        = list(string)
  description = "E-Mails der Studierenden (je eine WordPress-Instanz auf eigenem Port)"
  validation {
    condition     = length(var.student_emails) >= 1 && length(var.student_emails) <= 20
    error_message = "student_emails: Mindestens 1, maximal 20 E-Mail-Adressen."
  }
  validation {
    condition = alltrue([
      for email in var.student_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "Alle Einträge in student_emails müssen gültige E-Mail-Adressen sein."
  }
}

variable "flavor_name" {
  type        = string
  description = "OpenStack Flavor (VM-Größe) — eine VM für alle Studenten"
  default     = "gp1.medium"
  validation {
    condition     = contains(["gp1.small", "gp1.medium", "gp1.large"], var.flavor_name)
    error_message = "flavor_name: Muss 'gp1.small', 'gp1.medium' oder 'gp1.large' sein."
  }
}

variable "wordpress_version" {
  type        = string
  description = "WordPress Version"
  default     = "6.5"
}

variable "site_title" {
  type        = string
  description = "WordPress Site-Titel (gilt für alle Instanzen)"
  default     = "DHBW Web-Kurs"
}

# ==============================================================================
# INFRASTRUCTURE DEFAULTS (werden vom CloudStore gesetzt)
# ==============================================================================

variable "image_name" {
  type    = string
  default = "Ubuntu 22.04"
}

variable "network_name" {
  type    = string
  default = "NAT"
}

variable "external_network_name" {
  type    = string
  default = "DHBW"
}

variable "floating_ip_pool" {
  type    = string
  default = "DHBW"
}
