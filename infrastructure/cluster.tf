resource "linode_lke_cluster" "my-cluster" {
    label       = "my-k8s"
    k8s_version = "1.23"
    region      = "us-east"
    control_plane {
      high_availability = false
    }

    pool {
        type  = "g6-standard-2"
        count = 2
    }
}

resource "linode_token" "csi_token" {
  label  = "linode_volume_csi_access_token"
  scopes = "volumes:read_write"
  expiry = null
}

output "kubeconfig" {
  value = linode_lke_cluster.my-cluster.kubeconfig
  description = "Kubeconfig file (base64 encoded) for accessing the Linode Kubernetes cluster"
  sensitive = true
}

output "csi_token" {
  value = linode_token.csi_token.token
  description = "Linode API Token for creating and managing Linode Block Storage in the Kubernetes cluster using the CSI driver"
  sensitive = true
}