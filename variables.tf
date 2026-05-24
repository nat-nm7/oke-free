variable "compartment_id" {
  type = string
  default = "ocid1.tenancy.oc1..xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

variable "cluster_name" {
  type    = string
  default = "cluster1"
}

variable "node_pool_name" {
  type    = string
  default = "nodepool1"
}

variable "kubernetes_version" {
  type    = string
  default = "v1.35.2"
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx opc"
}

variable "node_image_id" {
  type    = string
  default = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaaerqj6kbgacp6wq2omhweui2nph6oepnx7i4on3hsr7qda7xwfayq"
}