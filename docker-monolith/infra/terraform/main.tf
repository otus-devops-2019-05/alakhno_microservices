provider "google" {
  version = "2.0.0"
  project = "${var.project}"
  region  = "${var.region}"
}

resource "google_compute_instance" "app" {
  name         = "reddit-app-${count.index + 1}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["reddit-app"]
  count        = "${var.instance_count}"

  boot_disk {
    initialize_params {
      image = "${var.instance_image}"
    }
  }

  network_interface {
    network       = "default"
    access_config = {}
  }

  metadata {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
}

resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app"]
}
