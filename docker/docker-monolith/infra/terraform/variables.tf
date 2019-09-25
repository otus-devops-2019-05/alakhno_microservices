variable project {
  description = "Project ID"
}

variable region {
  description = "Region"
  default     = "europe-west1"
}

variable zone {
  description = "Zone"
  default     = "europe-west1-b"
}

variable instance_image {
  description = "Instance disk image"
  default     = "ubuntu-1604-lts"
}

variable public_key_path {
  description = "Path to the public key used for ssh access"
}

variable instance_count {
  description = "Number of instances"
  default     = 1
}
