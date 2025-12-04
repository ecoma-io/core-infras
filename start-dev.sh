#!/bin/sh
set -e

ROOT_DIR=$(dirname "$0")

echo "🚀 Creating k3d cluster..."
k3d cluster delete core-infras
k3d cluster create --config - <<EOF
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: core-infras
servers: 1
agents: 0
image: rancher/k3s:v1.32.10-k3s1
network: core-infras
ports:
  - port: 80:80
    nodeFilters:
      - server:0
  - port: 443:443
    nodeFilters:
      - server:0
options:
  # k3d:
  #   disableLoadbalancer: true 
  k3s:
    extraArgs:    
      - arg: "--disable=local-storage"
        nodeFilters:
          - server:*     
EOF
echo "✅ k3d cluster created!"


echo "🚀 Installing core-infras components..."

install_component_overlay() {
  component="$1"
  dir="$ROOT_DIR/$component/overlays/dev"
  echo "🚀 Applying $component..."
  kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "$dir" | kubectl apply -f -
}

wait_for_pod_ready() {
  namespace="$1"
  label_selector="$2"
  echo "🚀 Waiting for pods in namespace '$namespace' with label '$label_selector' to be ready..."
  kubectl wait --for=condition=Ready pods -n "$namespace" -l "$label_selector" --timeout=300s
}

install_component_overlay argo-cd
wait_for_pod_ready argo-system app.kubernetes.io/name=argocd-serrver


echo "✅ core-infras components installed!\n"
echo "Run bellow command to check the status of the pods."
echo "kubectl get pods -A -w"
