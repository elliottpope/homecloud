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

output "spaces_endpoint" {
    value = digitalocean_spaces_bucket.nextcloud.bucket_domain_name
    description = "Fully Qualified Domain Name for the DigitalOcean Spaces Bucket"
}

output "spaces_name" {
    value = digitalocean_spaces_bucket.nextcloud.name
    description = "Name for the DigitalOcean Spaces bucket"
}