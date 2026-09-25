#!/bin/bash
set -e

DOCKER_USER="user"
DOCKER_PAT="password"

# echo "1. Installing Argo CD..."
# kubectl create namespace argocd || true
# kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# echo "2. Installing Gateway API CRDs..."
# kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.1.0" | kubectl apply -f -

# echo "3. Waiting for Argo CD API server to be ready..."
# kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "4. Authenticating Argo CD with Docker Hub OCI Registry..."
# kubectl exec -n argocd deployment/argocd-server -- argocd repo add \
#   oci://registry-1.docker.io/$DOCKER_USER \
#   --type oci \
#   --name dockerhub \
#   --username $DOCKER_USER \
#   --password $DOCKER_PAT


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: oci
  url: oci://registry-1.docker.io/$DOCKER_USER
  name: dockerhub
  username: $DOCKER_USER
  password: $DOCKER_PAT
EOF

echo "5. Deploying the Root App of Apps..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: oci://registry-1.docker.io/$DOCKER_USER/infra-manifests
    targetRevision: latest
    path: apps # Points to the folder containing the child apps
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "Bootstrap complete! Argo CD will now sync the platform."