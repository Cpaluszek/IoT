#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

# Define log colors
COLOR_RESET="\033[0m"
COLOR="\033[34m" # Blue

CLUSTER_NAME=$1

# Log function to standardize log output with timestamps
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


setup_k3d_cluster() {
    log "info" "creating cluster '${CLUSTER_NAME}'"
    if ! k3d cluster list | grep -q "${CLUSTER_NAME}"; then
        k3d cluster create $CLUSTER_NAME
        log "sucess" "cluster '${CLUSTER_NAME}' created successfully"
    fi
    k3d kubeconfig write $CLUSTER_NAME
    kubectl config use-context "k3d-"$CLUSTER_NAME
}

create_namespaces() {
    for name in "dev" "argocd"; do
        log "info" "creating namespace '${name}'"
        if ! kubectl get namespace | grep -q ${name}; then
            kubectl create namespace ${name}
            log "success" "namespace '${name}' created successfully"
        else
            log "info" "namespace '${name}' already exist"
        fi
    done
}

setup_argocd() {
    log "info" "installing argocd"
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    log "sucess" "Installed argocd successfully"

    log "info" "installing argocd-cli"
    if ! command -v argocd &> /dev/null; then
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        log "success" "Installed argocd-cli successfully"
    else
        log "info" "argocd-cli is already installed"
    fi
}

setup_k3d_cluster
create_namespaces
setup_argocd
