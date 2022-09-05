variable "public_ip" {
    type = string
    description = "Public facing IP of the Kubernetes Ingress Controller"
}

variable "cloudflare_zone_id" {
    type = string
    description = "Cloudflare Zone ID for the root domain"
}

# Cannot proxy DNS record since Cloudflare only covers one subdomain
resource "cloudflare_record" "nextcloud" {
  allow_overwrite = true
  name = "nextcloud.apps"
  proxied = false
  type = "A"
  value = "${var.public_ip}"
  zone_id = "${var.cloudflare_zone_id}"
}

resource "cloudflare_record" "www_nextcloud" {
  allow_overwrite = true
  name = "www.nextcloud.apps"
  proxied = false
  type = "CNAME"
  value = "nextcloud.apps.${var.domain}"
  zone_id = "${var.cloudflare_zone_id}"
}