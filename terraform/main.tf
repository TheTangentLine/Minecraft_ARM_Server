# 1. Open the Oracle Cloud VCN Firewall for Bedrock (UDP 19132)
resource "oci_core_security_list" "minecraft_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.minecraft_vcn.id
  display_name   = "minecraft-security-list"

  # Minecraft Bedrock UDP Port
  ingress_security_rules {
    protocol = "17" # 17 is UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 19132
      max = 19132
    }
  }
  
  # Standard SSH Port
  ingress_security_rules {
    protocol = "6" # 6 is TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
  
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# 2. Provision the ARM Instance
resource "oci_core_instance" "minecraft_server" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.A1.Flex"

  # 2 OCPUs and 12GB RAM is the sweet spot for 5-6 players
  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.minecraft_subnet.id
    assign_public_ip = true
  }

  depends_on = [
    oci_core_subnet.minecraft_subnet,
    oci_core_default_route_table.minecraft_rt,
  ]

  source_details {
    source_type = "image"
    source_id   = var.ubuntu_aarch64_image_id # The OCID for Ubuntu 22.04 ARM in ap-singapore-1
  }

  # Pass the cloud-init file into the VM
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
  }
}