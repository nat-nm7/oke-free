# VCN
resource "oci_core_vcn" "oke_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_id
  display_name   = "oke-vcn"
  dns_label      = "okevcn"
}

# インターネットゲートウェイ
resource "oci_core_internet_gateway" "oke_internet_gateway" {
  compartment_id = var.compartment_id
  display_name   = "oke-igw"
  vcn_id = oci_core_vcn.oke_vcn.id
}

# NATゲートウェイ
resource "oci_core_nat_gateway" "oke_nat_gateway" {
  compartment_id = var.compartment_id
  display_name   = "oke-ngw"
  vcn_id         = oci_core_vcn.oke_vcn.id
}

# サービスゲートウェイ
resource "oci_core_service_gateway" "oke_service_gateway" {
  compartment_id = var.compartment_id
  display_name   = "oke-sgw"
  services {
    # 東京リージョンの全サービス(All NRT Services In Oracle Services Network)
    # oci network service list --all --output tableで得られる
    service_id = "ocid1.service.oc1.ap-tokyo-1.aaaaaaaasijciseg5tzfchafero765m7yvl2dekfnayvyges6dnjnotlvzpa"
  }
  vcn_id = oci_core_vcn.oke_vcn.id
}

# ルート表(パブリックサブネット)
resource "oci_core_route_table" "oke_route_table_public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-public-routetable"
  route_rules {
    description       = "traffic to/from internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke_internet_gateway.id
  }
}

# ルート表(プライベートサブネット)
resource "oci_core_route_table" "oke_route_table_private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.oke_vcn.id
  display_name   = "oke-private-routetable"
  route_rules {
    description       = "traffic to the internet"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke_nat_gateway.id
  }
  route_rules {
    description       = "traffic to OCI services"
    destination       = "all-nrt-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.oke_service_gateway.id
  }
}

# LBサブネット(パブリック)
resource "oci_core_subnet" "service_lb_subnet" {
  cidr_block                 = "10.0.20.0/24"
  compartment_id             = var.compartment_id
  display_name               = "oke-svclbsubnet"
  dns_label                  = "lbsub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.oke_route_table_public.id
  security_list_ids          = [oci_core_security_list.service_lb_sec_list.id]
  vcn_id                     = oci_core_vcn.oke_vcn.id
}

# ノードサブネット(プライベート)
resource "oci_core_subnet" "node_subnet" {
  cidr_block                 = "10.0.10.0/24"
  compartment_id             = var.compartment_id
  display_name               = "oke-nodesubnet"
  dns_label                  = "nodesub"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.oke_route_table_private.id
  security_list_ids          = [oci_core_security_list.node_sec_list.id]
  vcn_id                     = oci_core_vcn.oke_vcn.id
}

# Kubernetes APIエンドポイントサブネット(プライベート)
resource "oci_core_subnet" "kubernetes_api_endpoint_subnet" {
  cidr_block                 = "10.0.0.0/28"
  compartment_id             = var.compartment_id
  display_name               = "oke-k8sApiEndpointsubnet"
  dns_label                  = "apisub"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.oke_route_table_private.id
  security_list_ids          = [oci_core_security_list.kubernetes_api_endpoint_sec_list.id]
  vcn_id                     = oci_core_vcn.oke_vcn.id
}

# LBサブネット用セキュリティリスト
resource "oci_core_security_list" "service_lb_sec_list" {
  compartment_id = var.compartment_id
  display_name   = "oke-svclbseclist"
  vcn_id         = oci_core_vcn.oke_vcn.id
}

# ノードサブネット用セキュリティリスト
resource "oci_core_security_list" "node_sec_list" {
  compartment_id = var.compartment_id
  display_name   = "oke-nodeseclist"
  egress_security_rules {
    description      = "Allow pods on one worker node to communicate with pods on other worker nodes"
    destination      = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = "false"
  }
  egress_security_rules {
    description      = "Access to Kubernetes API Endpoint"
    destination      = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = "6443"
      max = "6443"
    }
    stateless = "false"
  }
  egress_security_rules {
    description      = "Kubernetes worker to control plane communication"
    destination      = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = "12250"
      max = "12250"
    }
    stateless = "false"
  }
  egress_security_rules {
    description      = "Path discovery"
    destination      = "10.0.0.0/28"
    destination_type = "CIDR_BLOCK"
    protocol         = "1"
    icmp_options {
      type = "3"
      code = "4"
    }
    stateless = "false"
  }
  egress_security_rules {
    description      = "Allow nodes to communicate with OKE to ensure correct start-up and continued functioning"
    destination      = "all-nrt-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = "443"
      max = "443"
    }
    stateless = "false"
  }
  egress_security_rules {
    description      = "ICMP Access from Kubernetes Control Plane"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "1"
    icmp_options {
      type = "3"
      code = "4"
    }
    stateless = "false"
  }
  egress_security_rules {
    description      = "Worker Nodes access to Internet"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = "false"
  }
  ingress_security_rules {
    description = "Allow pods on one worker node to communicate with pods on other worker nodes"
    source      = "10.0.10.0/24"
    protocol    = "all"
    stateless   = "false"
  }
  ingress_security_rules {
    description = "Path discovery"
    source      = "10.0.0.0/28"
    protocol    = "1"
    icmp_options {
      type = "3"
      code = "4"
    }
    stateless = "false"
  }
  ingress_security_rules {
    description = "TCP access from Kubernetes Control Plane"
    source      = "10.0.0.0/28"
    protocol    = "6"
    stateless   = "false"
  }
  vcn_id = oci_core_vcn.oke_vcn.id
}

# Kubernetes APIエンドポイントサブネット用セキュリティリスト
resource "oci_core_security_list" "kubernetes_api_endpoint_sec_list" {
  compartment_id = var.compartment_id
  display_name   = "oke-apiseclist"
  egress_security_rules {
    description      = "Allow Kubernetes Control Plane to communicate with OKE"
    destination      = "all-nrt-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = "443"
      max = "443"
    }
    stateless = "false"
  }
  egress_security_rules {
    description      = "All traffic"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = "false"
  }
  egress_security_rules {
    description      = "Path discovery"
    destination      = "10.0.10.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "1"
    icmp_options {
      type = "3"
      code = "4"
    }
    stateless = "false"
  }
  ingress_security_rules {
    description = "External access to Kubernetes API endpoint"
    source      = "10.0.0.0/28"
    protocol    = "6"
    tcp_options {
      min = "6443"
      max = "6443"
    }
    stateless = "false"
  }
  ingress_security_rules {
    description = "Kubernetes worker to Kubernetes API endpoint communication"
    source      = "10.0.10.0/24"
    protocol    = "6"
    tcp_options {
      min = "6443"
      max = "6443"
    }
    stateless = "false"
  }
  ingress_security_rules {
    description = "Kubernetes worker to control plane communication"
    source      = "10.0.10.0/24"
    protocol    = "6"
    tcp_options {
      min = "12250"
      max = "12250"
    }
    stateless = "false"
  }
  ingress_security_rules {
    description = "Path discovery"
    source      = "10.0.10.0/24"
    protocol    = "1"
    icmp_options {
      type = "3"
      code = "4"
    }
    stateless = "false"
  }
  vcn_id = oci_core_vcn.oke_vcn.id
}