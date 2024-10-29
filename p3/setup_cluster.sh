#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

# Define log colors
COLOR_RESET="\033[0m"
COLOR="\033[34m" # Blue

CLUSTER_NAME=$1
APP_NAME="my-app"
APP_HOST="will-app"
PORT="8888"

if [ "$#" -ne 1 ]; then
    log "error" "Missing required arguments"
    echo "Usage: $0 <CLUSTER_NAME>"
    echo "Arguments:"
    echo "  CLUSTER_NAME    The name of the k3d cluster to create or use"
    exit 1
fi

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

check_dependencies() {
    for cmd in k3d kubectl; do
        if ! command -v $cmd &>/dev/null; then
            log "error" "$cmd is required but not installed. Please run the install script."
            exit 1
        fi
    done
}

setup_k3d_cluster() {
    log "info" "creating cluster '${CLUSTER_NAME}'"
    if ! k3d cluster list | grep -q "${CLUSTER_NAME}"; then
        k3d cluster create $CLUSTER_NAME --servers-memory 8G
        log "success" "cluster '${CLUSTER_NAME}' created successfully"
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
    log "success" "Installed argocd successfully"

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

wait_for_argocd_pods() {
    log "info" "Waiting for all ArgoCD pods to be ready..."
    while [[ $(kubectl get pods -n argocd --field-selector=status.phase=Running 2>/dev/null | wc -l) -lt $(kubectl get pods -n argocd --no-headers | wc -l) ]]; do
        log "info" "Still waiting for all ArgoCD pods to be ready..."
        sleep 5
    done
    log "success" "All ArgoCD pods are ready"
}

port_forward_argocd() {
    until [[ $(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l) -gt 0 ]]; do
        log "info" "No pods found in 'argocd' namespace yet. Waiting..."
        sleep 5
    done

    until kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; do
        log "info" "Waiting for argocd-server pod to enter Running state..."
        sleep 5
    done

    if sudo netstat -tulpn | grep -q :8080; then
        echo "Port 8080 is already in use. Trying to kill the process..."
        sudo pkill -f 'kubectl port-forward svc/argocd-server'
    fi
    if sudo lsof -i :8080 -sTCP:LISTEN -t | grep -q 'kubectl'; then
        log "info" "Another port-forwarding process for argocd-server is already in progress. Killing it..."
        sudo pkill -f 'kubectl.*port-forward.*8080'
        sleep 2
    fi

    sleep 5

    log "info" "Exposing argocd API Server..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &

    sleep 5

    while ! curl -s http://localhost:8080 > /dev/null; do
        echo "Waiting for port-forwarding for argocd-server to be ready..."
        sleep 5
    done
}

create_argocd_app() {
    ARGO_PSW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo ${ARGO_PSW} > argo_password.txt
    log "info" "argocd admin password written to argo_password.txt"

    argocd login localhost:8080 --username admin --password "$ARGO_PSW" --insecure

    log "info" "Creating argocd application..."
    # [`argocd app create` Command Reference - Argo CD - Declarative GitOps CD for Kubernetes](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_create/)
    argocd app create ${APP_NAME} --repo https://github.com/Cpaluszek/cpalusze.git --path app --dest-server https://kubernetes.default.svc --dest-namespace dev --upsert

    argocd app get ${APP_NAME} --grpc-web
    argocd app set ${APP_NAME} --sync-policy automated
    argocd app set ${APP_NAME} --auto-prune --allow-empty --grpc-web

    until (argocd app get ${APP_NAME} --grpc-web | grep -q "Healthy"); do
        log "info" "Waiting for ${APP_NAME} to become healthy..."
        sleep 5
    done
    log "success" "Both service and deployment are healthy"
}

print_infos() {
    argocd app get ${APP_NAME}
    kubectl get pods -n dev
    # Get ingress IP and map to /etc/hosts
    sudo sed -i.bak "/${APP_HOST}/d" /etc/hosts
    IP=$(kubectl get ingress -n dev ingress -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
    if [[ -n "$IP" ]]; then
        echo "$IP ${APP_HOST}" | sudo tee -a /etc/hosts
        log "success" "${APP_NAME} is available at ${APP_HOST} (IP: ${IP})"
    else
        log "warn" "Ingress IP for ${APP_NAME} not available; check ingress configuration."
    fi
}

setup_k3d_cluster
create_namespaces
setup_argocd
wait_for_argocd_pods
port_forward_argocd
create_argocd_app
print_infos
log "success" "${APP_NAME} is available at ${APP_HOST}:${PORT}"

