#!/bin/bash

# 1. Update system
echo "📦 Updating system..."
sudo apt-get update
sudo apt-get install -y curl

# 2. Install Docker (Universal Method)
# Using get-docker.sh is safer than apt-repo for Debian Trixie/Ubuntu mix
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
else
    echo "✅ Docker is already installed."
fi

# 3. Install K3d and Kubectl
echo "🔧 Installing K3d and Kubectl..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 4. Clean up old cluster (FIX "Already Exists" error)
echo "🧹 Cleaning up old cluster..."
k3d cluster delete gitops-cluster 2> /dev/null || true

# 5. Create K3d Cluster
echo "🚀 Creating K3d cluster..."
# We disable Traefik to avoid conflicts
k3d cluster create gitops-cluster \
    --k3s-arg "--disable=traefik@server:0"

# 6. Create Namespaces
echo "📂 Creating namespaces..."
kubectl create namespace argocd

# 7. Install ArgoCD
echo "🐙 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD server to start (timeout 5m)..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 8. Get Admin Password (FIXED METHOD)
# We use kubectl because 'argocd' CLI is not installed
echo "🔑 Retrieving admin password..."
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "--- SETUP COMPLETE ---"
echo "Username: admin"
echo "Password: $PASSWORD"
echo "----------------------"
echo "To access ArgoCD, run this command in a NEW terminal:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then open: https://localhost:8080"