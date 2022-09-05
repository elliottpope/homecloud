variable "digitalocean_spaces_region" {
    type = string
    description = "Region to deploy DigitalOcean Spaces resources to"
    default = "fra1"
}

resource "random_uuid" "spaces_id" {}


resource "digitalocean_spaces_bucket" "nextcloud" {
  name   = "nextcloud-${random_uuid.spaces_id.result}"
  region = var.digitalocean_spaces_region
  cors_rule {
    allowed_origins = [ "https://nextcloud.apps.${var.domain}" ]
    allowed_methods = [ "GET", "PUT", "POST", "DELETE", "HEAD" ]
  }
}

data "linode_object_storage_cluster" "primary" {
    id = "us-east-1"
}

resource "linode_object_storage_key" "nextcloud_bucket_access_keys" {
  label = "image-access"
  bucket_access {
    bucket_name = "${linode_object_storage_bucket.nextcloud.label}"
    cluster = data.linode_object_storage_cluster.primary.id
    permissions = "read_write"
  }
}

resource "linode_object_storage_bucket" "nextcloud" {
  cluster = data.linode_object_storage_cluster.primary.id
  label   = "nextcloud-${random_uuid.spaces_id.result}"
}

output "spaces_endpoint" {
    value = digitalocean_spaces_bucket.nextcloud.bucket_domain_name
    description = "Fully Qualified Domain Name for the DigitalOcean Spaces Bucket"
}

output "spaces_name" {
    value = digitalocean_spaces_bucket.nextcloud.name
    description = "Name for the DigitalOcean Spaces bucket"
}

output "bucket_endpoint" {
    value = linode_object_storage_bucket.nextcloud.hostname
    description = "Domain Name for the Linode Object Storage Bucket"
}

output "bucket_name" {
    value = linode_object_storage_bucket.nextcloud.label
    description = "Name for the Linode Object Storage bucket"
}

output "bucket_access_key" {
  value = linode_object_storage_key.nextcloud_bucket_access_keys.access_key
  description = "Access Key ID for the Nextcloud Linode Object Storage bucket"
  sensitive = true
}

output "bucket_secret_key" {
  value = linode_object_storage_key.nextcloud_bucket_access_keys.secret_key
  description = "Secret Key for the Nextcloud Linode Object Storage bucket"
  sensitive = true
}

output "bucket_domain" {
  value = data.linode_object_storage_cluster.primary.domain
  description = "Base domain of the Linode Object Storage cluster"
}