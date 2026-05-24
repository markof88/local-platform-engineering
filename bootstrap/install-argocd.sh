#!/bin/bash
# Run this once to install ArgoCD on the mgmt cluster
# ArgoCD is platform infrastructure, not managed by sveltos

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd --create-namespace --version 9.5.15

echo "ArgoCD installed. Now apply the ArgoCD Application:"
echo "kubectl apply -f bootstrap/argocd-app-sveltos.yaml"