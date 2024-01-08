terraform {
  backend "gcs" {
    bucket = "soofs-infra-state"
    prefix = "cloud-sql-poc/terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.7.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "google" {
  project = "soofs-infra"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "random_password" "root_sql_password" {
  length = 20
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_compute_network" "default_vpc" {
  name = "default-vpc"
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.default_vpc.id
}


resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.default_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "default" {
  name                = "cloud-sql-poc-${random_id.db_name_suffix.hex}"
  database_version    = "POSTGRES_15"
  count               = 1
  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_HDD"


    ip_configuration {
      ipv4_enabled                                  = false
      enable_private_path_for_google_cloud_services = true
      private_network                               = google_compute_network.default_vpc.id
    }

  }

  root_password = random_password.root_sql_password.result
}


resource "google_sql_database" "default" {
  name     = "defaultdb"
  instance = google_sql_database_instance.default[0].name
}

resource "random_password" "functions_user_password" {
  length = 8
}

resource "google_sql_user" "functions_user" {
  instance = google_sql_database_instance.default[0].name
  name     = "functions_user"
  password = random_password.functions_user_password.result
}

resource "google_secret_manager_secret" "sql_connection_string" {
  secret_id = "SQL_CONNECTION_STRING"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "sql_connection_string" {
  secret      = google_secret_manager_secret.sql_connection_string.id
  secret_data = google_sql_database_instance.default[0].connection_name
}

resource "google_secret_manager_secret" "functions_user_password" {
  secret_id = "SQL_FUNCTIONS_USER_PASSWORD"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "functions_user_password" {
  secret      = google_secret_manager_secret.functions_user_password.id
  secret_data = random_password.functions_user_password.result
}

resource "google_secret_manager_secret" "functions_user" {
  secret_id = "SQL_FUNCTIONS_USER"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "functions_user" {
  secret      = google_secret_manager_secret.functions_user.id
  secret_data = google_sql_user.functions_user.name
}


output "sql_connection_secret_id" {
  value = google_secret_manager_secret.sql_connection_string.id
}

output "password_secret_id" {
  value = google_secret_manager_secret.functions_user_password.id
}

output "user_secret_id" {
  value = google_secret_manager_secret.functions_user.id
}

