#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

# Define log colors
COLOR_RESET="\033[0m"
COLOR="\033[34m" # Blue

HOST_ENTRY="127.0.0.1 gitlab.k3d.gitlab.com"

log() {
    case $1 in
        "info")
            echo -e "${COLOR}$(date +"%Y-%m-%d %H:%M:%S") - INFO: $2${COLOR_RESET}"
            ;;
        "warn")
            echo -e "${COLOR}$(date +"%Y-%m-%d %H:%M:%S") - WARNING: $2${COLOR_RESET}"
            ;;
        "error")
            echo -e "${COLOR}$(date +"%Y-%m-%d %H:%M:%S") - ERROR: $2${COLOR_RESET}"
            ;;
        "success")
            echo -e "${COLOR}$(date +"%Y-%m-%d %H:%M:%S") - SUCCESS: $2${COLOR_RESET}"
            ;;
        *)
            echo -e "$(date +"%Y-%m-%d %H:%M:%S") - $2"
            ;;
    esac
}

if ! command -v helm &> /dev/null; then
    echo -e "Installing Helm..."
    sudo snap install helm --classic
else
    log "info" "Helm is already installed"
fi

if ! kubectl get namespace gitlab > /dev/null 2>&1; then
    log "info" "Creating gitlab namespace"
    kubectl create namespace gitlab
fi
kubectl get namespaces

if ! grep -q "$HOST_ENTRY" /etc/hosts; then
    log "info" "Adding host entry to /etc/hosts"
    echo "$HOST_ENTRY" | sudo tee -a /etc/hosts
else
    log "info" "${HOST_ENTRY} is already in /etc/hosts"
fi

log "info" "Deploying gitlab using helm"
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
    -f https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml \
    --namespace gitlab \
    --timeout 600s \
    --set global.hosts.domain=k3d.gitlab.com \
    --set global.hosts.externalIP=0.0.0.0 \
    --set global.hosts.https=false

# global.shell.authToken

# Wait for GitLab to be ready
log "info" "Waiting for GitLab to be ready..."
kubectl wait --for=condition=ready --timeout=1500s pod -l app=webservice -n gitlab

# Retrieve GitLab initial root password
GITLAB_PSW=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 -d)
echo "${GITLAB_PSW}" > gitlab_root_password.txt
log "info" "GitLab root password written to gitlab_root_password.txt"

# Set up port forwarding for GitLab
if [ -n "$(sudo lsof -i :80)" ]; then
    log "info" "Port forwarding already running, recreating..."
    sudo pkill -f "kubectl.*port-forward.*80:8181"
fi

log "info" "Setting up port forwarding for GitLab..."
sudo kubectl port-forward svc/gitlab-webservice-default -n gitlab 80:8181 &>/dev/null &

