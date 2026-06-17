data "oci_core_vnic_attachments" "minecraft_vnic_attachments" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.minecraft_server.id
}

data "oci_core_vnic" "minecraft_vnic" {
  vnic_id = data.oci_core_vnic_attachments.minecraft_vnic_attachments.vnic_attachments[0].vnic_id
}

output "public_ip" {
  description = "Public IP of the Minecraft server (Bedrock client endpoint, not CD SSH host)"
  value       = data.oci_core_vnic.minecraft_vnic.public_ip_address
}

output "instance_id" {
  description = "OCID of the provisioned instance"
  value       = oci_core_instance.minecraft_server.id
}
