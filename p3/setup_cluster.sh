#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

# Define log colors
COLOR_RESET="\033[0m"
COLOR="\033[34m" # Blue

CLUSTER_NAME=$1
APP_NAME="my-app"
APP_HOST="will-app"

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

wait_for_argocd_pods() {
    desired_ready_count=$(kubectl get pods -n argocd --no-headers=true | awk '/Running/ && /1\/1/ {++count} END {print count}')
    total_pods=$(kubectl get pods -n argocd --no-headers=true | wc -l)

    while [[ "$desired_ready_count" -ne "$total_pods" ]]; do
        echo "Waiting for all pods to be ready..."
        desired_ready_count=$(kubectl get pods -n argocd --no-headers=true | awk '/Running/ && /1\/1/ {++count} END {print count}')
        total_pods=$(kubectl get pods -n argocd --no-headers=true | wc -l)
        sleep 5
    done
    log "success" "argocd pods are ready"
}

port_forward_argocd() {
    if sudo netstat -tulpn | grep -q :8080; then
        echo "Port 8080 is already in use. Trying to kill the process..."
        sudo pkill -f 'kubectl port-forward svc/argocd-server'
    fi
    if sudo lsof -i :8080 -sTCP:LISTEN -t | grep -q 'kubectl'; then
        log "info" "Another port-forwarding process for argocd-server is already in progress. Killing it..."
        sudo pkill -f 'kubectl.*port-forward.*8080'
        sleep 2
    fi

    log "info" "Exposing argocd API Server..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 &>/dev/null &

    // TODO: check why this does not work
    while ! curl -s http://localhost:8080 > /dev/null; do
        echo "Waiting for port-forwarding for argocd-server to be ready..."
        sleep 2
    done
    log "sucess " "Exposing argocd API Server..."
}

create_argocd_app() {
    ARGO_PSW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log "info" "argocd admin password written to argo_password.txt"
    echo ${ARGO_PSW} > argo_password.txt

    argocd login localhost:8080 --username admin --password "$ARGO_PSW" --insecure


    log "info" "Creating argocd application..."
    # [`argocd app create` Command Reference - Argo CD - Declarative GitOps CD for Kubernetes](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_create/)
    argocd app create ${APP_NAME} --repo https://github.com/Cpaluszek/cpalusze.git --path app --dest-server https://kubernetes.default.svc --dest-namespace dev --upsert

    argocd app get ${APP_NAME} --grpc-web
    argocd app set ${APP_NAME} --sync-policy automated
    argocd app set ${APP_NAME} --auto-prune --allow-empty --grpc-web

    while ! (argocd app get ${APP_NAME} --grpc-web | grep -q "Service.*Healthy" && argocd app get ${APP_NAME} --grpc-web | grep -q "Deployment.*Healthy"); do
        log "info" "Waiting for the app to become healthy..."
        sleep 2
    done
    log "success" "Both service and deployment are healthy"

    # Get ingress IP and map to /etc/hosts
    IP=$(kubectl get ingress -n dev ingress -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
    echo "$IP ${APP_HOST}" | sudo tee -a /etc/hosts

    log "sucess" "${APP_NAME} is available at ${APP_HOST}"
}

print_infos() {
    argocd app get ${APP_NAME}
    kubectl get pods -n dev
}

setup_k3d_cluster
create_namespaces
setup_argocd
wait_for_argocd_pods
port_forward_argocd
create_argocd_app
print_infos
