#!/bin/bash

# update system
echo "Updating system..."
sudo apt-get update
sudo apt-get install -y curl

# install docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
else
    echo "Docker is already installed."
fi

# install K3d and Kubectl
echo "Installing K3d and Kubectl..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# destroy cluster if already exists
echo "Cleaning up old cluster..."
k3d cluster delete gitops-cluster 2> /dev/null || true

# create a new K3d cluster
echo "Creating K3d cluster..."
# # We disable Traefik to avoid conflicts
k3d cluster create gitops-cluster --k3s-arg "--disable=traefik@server:0"

# create argocd namespace
echo "Creating namespaces..."
kubectl create namespace argocd

# install ArgoCD
echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# wait for ArgoCD to be ready
echo "Waiting for ArgoCD server to start (timeout 5m)..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# deploy application via ArgoCD
echo "Deploying application via ArgoCD..."
kubectl apply -f ../confs/app.yaml

# waiting for the app to be synced and running
echo "Waiting for ArgoCD to sync and App to be ready..."

while ! kubectl get ns dev > /dev/null 2>&1; do
    sleep 2
done

kubectl wait --for=condition=available deployment --all -n dev --timeout=300s
echo "App is synced and running!"

# get Admin Password
# we use kubectl because 'argocd' CLI is not installed
echo "Retrieving admin password..."
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "--- SETUP COMPLETE ---"
echo "Username: admin"
echo "Password: $PASSWORD"
echo "----------------------"
echo "To access ArgoCD, run this command in a NEW terminal:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then open: https://localhost:8080"
echo "----------------------"
echo "To access the app :"
echo "kubectl port-forward svc/wilplayground-service -n dev 8888:8888"
echo "Then open: http://localhost:8888"
echo "----------------------"