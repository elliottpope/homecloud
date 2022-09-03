# Personal DigitalOcean K8 Cluster

## Prerequisites

1. A DigitalOcean account with a read-write and read-only Personal Access Token
2. DigitalOcean Spaces Access and Secret keys
3. `terraform` installed
4. `kubectl` installed
5. `jq` installed
6. `doctl` installed 
7. `helm` installed

## Create the Cluster

1. Create the K8 cluster and DigitalOcean VPC
2. Deploy `cert-manager`, `nginx-ingress`, `linkerd` using Helm
3. Point Cloudflare DNS to K8 Ingress and create DigitalOcean Spaces for Nextcloud and Vault
3. Create the self signed CA issuer for bootstrapping Vault
4. Deploy Vault, Postgres, and Redis Operators
5. Create Postgres resource
6. Create Vault resource
7. Create Redis resource
9. Deploy Nextcloud as a StatefulSet


### Create DigitalOcean K8 cluster

```
doctl kubernetes cluster create <cluster name> --node-pool "name=<pool name>;count=2;size=s-2vcpu-2gb" --region nyc3 --wait --maintenance-window "sunday=00:00" --auto-upgrade
```

### Add NGINX Ingress, Cert Manager, and Linkerd
```
# NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm upgrade ingress-nginx ingress-nginx/ingress-nginx --install --namespace ingress-nginx --create-namespace -f ingress.yaml --wait

# Cert Manager
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace -f cert-manager.yaml --wait
kubectl apply -f self-signed-ca.yaml
kubectl apply -f lets-encrypt-issuers.yaml

# Linkerd
# TODO: use Helm to lower resource usage
#helm repo add linkerd https://helm.linkerd.io/stable

#helm install linkerd2 --set identity.externalCA=true linkerd/linkerd2
linkerd install --identity-external-issuer=true (--set proxyInit.runAsRoot=true) | kubectl apply -f -
```

### Terraform DNS and DigitalOcean Spaces

```
export SPACES_ACCESS_KEY_ID=
export SPACES_SECRET_ACCESS_KEY=

export CLOUDFLARE_API_TOKEN=

export LINODE_TOKEN=


# Create any external resources required by K8 cluster (i.e. AWS resources)
cd infrastructure
export PUBLIC_IP=$(kubectl describe service ingress-nginx-controller -n ingress-nginx | grep "LoadBalancer Ingress" | awk -F: '{printf $2}' | tr -d ' ')

terraform init
terraform plan --var public_ip=${PUBLIC_IP} --var-file main.tfvars -out cluster.plan
terraform apply cluster.plan

terraform output -raw kubeconfig | base64 -d > ~/.kube/linode.kubeconfig
chmod ug-r ~/.kube/linode.kubeconfig
```

### Create Namespaces, Certificate Issuers, and Operators
```
kubectl apply -f namespace.yaml

# Deploy Vault 
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
helm upgrade --install vault-operator banzaicloud-stable/vault-operator --namespace operators --set resources.requests.memory=32Mi --wait
helm upgrade --namespace vault --install vault-secrets-webhook banzaicloud-stable/vault-secrets-webhook --set resources.requests.memory=32Mi --wait

# Deploy Postgres Operator
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm upgrade postgres-operator postgres-operator-charts/postgres-operator --install --namespace operators --set configKubernetes.enable_cross_namespace_secret=true  --set resources.requests.memory=32Mi --wait

# Install Redis Operator
helm repo add ot-helm https://ot-container-kit.github.io/helm-charts/
helm upgrade redis-operator ot-helm/redis-operator --install --namespace operators --set resources.requests.cpu=20m --set resources.requests.memory=32Mi --wait

# Install Metrics Server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server (--set args[0]="--kubelet-insecure-tls=true" --set args[1]="--kubelet-preferred-address-types=InternalIP") --atomic --wait 
```

### Deploy Vault and Configure Secrets
```
kubectl apply -f vault.yaml

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

# Deploy Postgres and Redis
```
kubectl apply -f postgres.yaml

kubectl create secret generic redis-secret -n database --from-literal=password="vault:secret/data/redis#PASSWORD"
kubectl apply -f redis.yaml
```

### Deploy Nextcloud
```
cd apps
kubectl apply -f nextcloud.yaml
```