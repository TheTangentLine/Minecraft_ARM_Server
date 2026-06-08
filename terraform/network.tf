resource "oci_core_vcn" "minecraft_vcn" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "minecraft-vcn"
  dns_label      = "minecraftvcn"
}

resource "oci_core_internet_gateway" "minecraft_igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.minecraft_vcn.id
  display_name   = "minecraft-igw"
  enabled        = true
}

resource "oci_core_default_route_table" "minecraft_rt" {
  manage_default_resource_id = oci_core_vcn.minecraft_vcn.default_route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.minecraft_igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

resource "oci_core_subnet" "minecraft_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.minecraft_vcn.id
  cidr_block                 = var.subnet_cidr
  display_name               = "minecraft-subnet"
  dns_label                  = "minecraftsub"
  prohibit_public_ip_on_vnic = false
  security_list_ids          = [oci_core_security_list.minecraft_sl.id]

  depends_on = [oci_core_security_list.minecraft_sl]
}
