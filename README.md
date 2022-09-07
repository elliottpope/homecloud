# Personal DigitalOcean K8 Cluster

## Prerequisites

1. A Linode account with an API token with admin permissions
3. `terraform` installed
4. `kubectl` installed
5. `jq` installed
6. `yq` installed

### Create the Kubernetes Cluster and Other Infrastructure

```
cd infrastructure/terraform
terraform init

export SPACES_ACCESS_KEY_ID=
export SPACES_SECRET_ACCESS_KEY=

export CLOUDFLARE_API_TOKEN=

export LINODE_TOKEN=

export PUBLIC_IP=$(kubectl describe service ingress-nginx-controller -n ingress-nginx | grep "LoadBalancer Ingress" | awk -F: '{printf $2}' | tr -d ' ')

erraform plan --var public_ip=${PUBLIC_IP:} --var-file main.tfvars -out cluster.plan
terraform apply cluster.plan

terraform output -raw kubeconfig | base64 -d > ~/.kube/linode.kubeconfig
chmod ug-r ~/.kube/linode.kubeconfig
```

### Bootstrap Flux

#### Prerequisites

1. This must be a Git repository hosted on GitHub
2. There must be a private GitHub repository for overlays with sensitive information (here `elliottpope/homecloud-private`)
2. You must have a Personal Access Token (PAT) with `repo` permissions and the user must be an admin of the target repo

#### Bootstrap the Cluster

```
export GITHUB_TOKEN=

flux bootstrap github --owner=my-github-username --repository=my-repository --personal
```

#### Generate the Flux GPG Key for Sealed Secrets

```
gpg ...

export GPG_KEY_ID=
```

#### Generate the Private Repository SSH Key

```
flux -n flux-system create secret git private-overlays-auth --url=ssh://git@github.com/elliottpope/homecloud-private --export > ./infrastructure/private-overlays-auth.yaml

yq e '.stringData."identity.pub"' private-overlays-ssh.yaml > private-overlays-ssh.pub
gh repo deploy-key add private-overlays-ssh.pub -R elliottpope/homecloud-private
```

### Deploy Vault and Configure Secrets
```
export VAULT_TOKEN=$(kubectl get secret -n vault -o json vault-unseal-keys | jq -r '.data["vault-root"]' | base64 -d)

# Add Redis password
`vault kv put secret/redis PASSWORD=`

# Add Nextcloud Admin Creds
`kubectl exec -it -n vault vault-0 -c vault -- /bin/sh -c "VAULT_CACERT= VAULT_ADDR=http://127.0.0.1:8200 vault login ${VAULT_TOKEN} && VAULT_CACERT= VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/nextcloud/admin USERNAME= PASSWORD=`

# Add Digital Ocean Spaces Access Keys
`vault kv put secret/nextcloud/aws ACCESS_KEY=${SPACES_ACCESS_KEY_ID} SECRET_KEY=${SPACES_SECRET_ACCESS_KEY} BUCKET=$(terraform output -raw spaces_name) ENDPOINT=$(terraform output -raw spaces_endpoint)`
# Or Linode 
kubectl exec -it -n vault vault-0 -c vault -- /bin/sh -c "VAULT_CACERT= VAULT_ADDR=http://127.0.0.1:8200 vault login ${VAULT_TOKEN} && VAULT_CACERT= VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/nextcloud/aws ACCESS_KEY=$(terraform output -raw bucket_access_key) SECRET_KEY=$(terraform output -raw bucket_secret_key) BUCKET=$(terraform output -raw bucket_name) ENDPOINT=$(terraform output -raw bucket_endpoint) DOMAIN=$(terraform output -raw bucket_domain)"

# Add domain name
`vault kv put secret/domain DOMAIN=`
```
