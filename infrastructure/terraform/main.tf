terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.17.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
    linode = {
      source = "linode/linode"
      version = "1.29.2"
    }
  }
}

provider "digitalocean" {
}

variable "domain" {
  type        = string
  description = "Root domain for the apps in the cluster"
}
