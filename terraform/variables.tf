variable "compartment_id" {
  type        = string
  description = "OCI compartment OCID"
}

variable "region" {
  type        = string
  description = "OCI region"
  default     = "ap-singapore-1"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for the ubuntu user"
}

variable "ubuntu_aarch64_image_id" {
  type        = string
  description = "OCID of Ubuntu 22.04 aarch64 image in your region"
}

variable "tailscale_authkey" {
  type        = string
  description = "Tailscale auth key used by cloud-init for first boot tailnet join"
  sensitive   = true
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block for the VCN"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet"
  default     = "10.0.1.0/24"
}
