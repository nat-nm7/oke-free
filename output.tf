output "cluster_id" {
  value = oci_containerengine_cluster.oke_cluster.id
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.oke_node_pool.id
}

output "oke_image_id" {
  value = data.oci_core_images.oke_images.images[0].id
}

output "vcn_id" {
  value = oci_core_vcn.oke_vcn.id
}

output "subnet_ids" {
  value = {
    api_subnet  = oci_core_subnet.kubernetes_api_endpoint_subnet.id
    node_subnet = oci_core_subnet.node_subnet.id
    lb_subnet   = oci_core_subnet.service_lb_subnet.id
  }
}