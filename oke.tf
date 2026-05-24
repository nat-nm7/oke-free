# アベイラビリティドメインの取得
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# OKEクラスタ(基本クラスタ)
resource "oci_containerengine_cluster" "oke_cluster" {
  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }
  compartment_id = var.compartment_id
  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.kubernetes_api_endpoint_subnet.id
  }
  freeform_tags = {
    "OKEclusterName" = var.cluster_name
  }
  kubernetes_version = var.kubernetes_version
  name               = var.cluster_name
  options {
    admission_controller_options {
      is_pod_security_policy_enabled = false
    }
    persistent_volume_config {
      freeform_tags = {
        "OKEclusterName" = var.cluster_name
      }
    }
    service_lb_config {
      freeform_tags = {
        "OKEclusterName" = var.cluster_name
      }
    }
    service_lb_subnet_ids = [oci_core_subnet.service_lb_subnet.id]
  }
  # 基本クラスタにする
  type   = "BASIC_CLUSTER"
  vcn_id = oci_core_vcn.oke_vcn.id
}

# ノードプール
resource "oci_containerengine_node_pool" "oke_node_pool" {
  compartment_id     = var.compartment_id
  cluster_id         = oci_containerengine_cluster.oke_cluster.id
  name               = var.node_pool_name
  kubernetes_version = var.kubernetes_version
  ssh_public_key     = var.ssh_public_key
  node_shape         = "VM.Standard.A1.Flex"
  node_shape_config {
    memory_in_gbs = 12
    ocpus         = 2
  }
  node_source_details {
    source_type = "IMAGE"
    image_id = var.node_image_id
    boot_volume_size_in_gbs = 50
  }
  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.node_subnet.id
    }
    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [oci_core_subnet.node_subnet.id]
    }
    size = 2
  }
}