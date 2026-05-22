# Local Platform Engineering with vind, Sveltos and ArgoCD

A fully local Kubernetes platform engineering demo running entirely in Docker.
No cloud account needed. No cost. Runs on your laptop.

## What this demo shows

- Multiple Kubernetes clusters running locally using vind (vCluster in Docker)
- Sveltos managing deployments across clusters using label-based targeting
- ArgoCD bootstrapped by Sveltos for GitOps sync
- Full GitOps loop: push to Git → ArgoCD syncs → Sveltos deploys

## Architecture

```
GitHub Repo
    ↓ (ArgoCD syncs ClusterProfiles)
mgmt cluster (vind)
    ↓ (Sveltos deploys based on labels)
dev cluster (vind)     → podinfo green, 2 replicas
staging cluster (vind) → podinfo blue, 2 replicas
```

## Prerequisites

- Docker Desktop
- vCluster CLI v0.34.0+
- kubectl
- helm
- sveltosctl v1.10.0+

## Installation

### 1. Install vCluster CLI

```bash
vcluster upgrade --version v0.34.0
vcluster use driver docker
vcluster platform start
```

### 2. Create clusters

```bash
sudo vcluster create mgmt
sudo vcluster create dev
sudo vcluster create staging
```

> **Note:** `sudo` is required on Mac for LoadBalancer support.

### 3. Save kubeconfigs

```bash
vcluster connect mgmt --print > /tmp/mgmt.yaml
vcluster connect dev --print > /tmp/dev.yaml
vcluster connect staging --print > /tmp/staging.yaml
```

### 4. Fix Docker networking

Each vCluster runs in an isolated Docker network. Connect them to a shared network so Sveltos on mgmt can reach dev and staging:

```bash
docker network create vcluster-shared
docker network connect vcluster-shared vcluster.cp.mgmt
docker network connect vcluster-shared vcluster.cp.dev
docker network connect vcluster-shared vcluster.cp.staging
```

Get the shared network IPs:

```bash
docker inspect vcluster.cp.dev | grep -A 15 vcluster-shared
docker inspect vcluster.cp.staging | grep -A 15 vcluster-shared
```

Fix kubeconfigs with shared network IPs and correct port (8443):

```bash
# Replace with your actual IPs from above
sed 's/localhost:PORT/172.18.0.3:8443/' /tmp/dev.yaml > /tmp/dev-fixed.yaml
sed 's/localhost:PORT/172.18.0.4:8443/' /tmp/staging.yaml > /tmp/staging-fixed.yaml
```

### 5. Install Sveltos

```bash
export KUBECONFIG=/tmp/mgmt.yaml

helm repo add projectsveltos https://projectsveltos.github.io/helm-charts
helm repo update
helm install projectsveltos projectsveltos/projectsveltos \
  -n projectsveltos \
  --create-namespace \
  --version=1.10.0

kubectl get pods -n projectsveltos
```

### 6. Label mgmt cluster

```bash
kubectl label sveltoscluster mgmt -n mgmt type=mgmt
```

### 7. Register dev and staging clusters

```bash
kubectl create namespace dev
kubectl create namespace staging

sveltosctl register cluster \
  --namespace=dev \
  --cluster=dev \
  --kubeconfig=/tmp/dev-fixed.yaml \
  --labels=env=dev

sveltosctl register cluster \
  --namespace=staging \
  --cluster=staging \
  --kubeconfig=/tmp/staging-fixed.yaml \
  --labels=env=staging

kubectl get sveltoscluster -A --show-labels
```

### 8. Apply Sveltos ClusterProfiles

```bash
kubectl apply -f sveltos/mgmt/clusterprofile-argocd.yaml
kubectl apply -f sveltos/mgmt/argocd-app-sveltos.yaml
```

Sveltos installs ArgoCD on mgmt. ArgoCD then syncs the ClusterProfiles from this repo to mgmt. Sveltos deploys podinfo to dev and staging automatically.

## Verify

```bash
# Check all clusters are ready
kubectl get sveltoscluster -A

# Check deployments
kubectl get clustersummary -A

# Access podinfo on dev (green)
export KUBECONFIG=/tmp/dev.yaml
kubectl port-forward svc/podinfo 9898:9898 -n podinfo
open http://localhost:9898

# Access podinfo on staging (blue)
export KUBECONFIG=/tmp/staging.yaml
kubectl port-forward svc/podinfo 9898:9898 -n podinfo
open http://localhost:9898
```

## GitOps in action

To see the full GitOps loop working, edit any ClusterProfile in `sveltos/clusters/` and push to main. ArgoCD will sync the change to mgmt within 3 minutes. Sveltos will propagate it to the target clusters automatically.

## Key gotchas

1. Use `sudo vcluster create` on Mac for LoadBalancer support
2. Each vCluster gets its own isolated Docker network — shared network is required
3. vCluster API server listens on port `8443` not `6443`
4. Use localhost kubeconfigs for local kubectl access, container IPs for Sveltos registration
5. Sveltos `values` field requires pipe `|` — nested YAML map will not work

## Tools used

- [vind](https://github.com/loft-sh/vcluster) - vCluster in Docker
- [Sveltos](https://github.com/projectsveltos/sveltos) - Kubernetes add-on controller
- [ArgoCD](https://argoproj.github.io/cd/) - GitOps continuous delivery
- [Podinfo](https://github.com/stefanprodan/podinfo) - Demo microservice