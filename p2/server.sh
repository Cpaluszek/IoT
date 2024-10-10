#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

# Define log colors
COLOR_RESET="\033[0m"
COLOR="\033[34m" # Blue

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

# Check for SERVER_IP argument and validate
SERVER_IP=$1

if [ -z "$SERVER_IP" ]; then
    log "error" "SERVER_IP is not provided."
    exit 1
fi

if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log "error" "Invalid SERVER_IP format."
    exit 1
fi

# Update package index
log "info" "Updating package index..."
sudo apt-get update

# Function to install curl
install_curl() {
    if ! command -v curl &> /dev/null; then
        log "info" "curl could not be found. Installing curl..."
        sudo apt-get install -y curl || {
            log "error" "Failed to install curl."
            exit 1
        }
    else
        log "info" "curl is already installed."
    fi
}

# Function to install K3s
install_k3s() {
    if command -v k3s >/dev/null 2>&1; then
        log "info" "K3s is already installed."
    else
        log "info" "K3s is not installed. Proceeding with installation..."

        # K3s configuration
        export INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 --node-ip=$SERVER_IP"

        # Install K3s
        if curl -sfL https://get.k3s.io | sh -; then
            log "success" "K3s MASTER installation SUCCEEDED."
        else
            log "error" "K3s MASTER installation FAILED."
            exit 1
        fi
    fi

    mkdir -p $HOME/.kube
    cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
}

# Function to wait for K3s to be running
wait_for_k3s() {
    TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
    MAX_WAIT=60
    WAIT_INTERVAL=5
    ELAPSED_TIME=0

    log "info" "Waiting for K3s to start and create the token file..."

    # Wait for the token file to be created
    while [ ! -f "$TOKEN_FILE" ]; do
        if [ $ELAPSED_TIME -ge $MAX_WAIT ]; then
            log "error" "Token file was not found after waiting $MAX_WAIT seconds."
            exit 1
        fi

        log "warn" "Token file not found yet... ($ELAPSED_TIME seconds elapsed)"
        sleep $WAIT_INTERVAL
        ELAPSED_TIME=$((ELAPSED_TIME + WAIT_INTERVAL))
    done
    log "success" "K3s MASTER is running."
}

# Function to update /etc/hosts file
update_hosts() {
    log "info" "Updating /etc/hosts file..."
    {
        echo "$SERVER_IP app1.com"
        echo "$SERVER_IP app2.com"
        echo "$SERVER_IP app3.com"
    } | sudo tee -a /etc/hosts > /dev/null
    log "success" "/etc/hosts updated."
}

# Function to apply Kubernetes manifests
apply_manifests() {
    log "info" "Applying Kubernetes manifests..."
    for app in app1 app2 app3 ingress; do
        kubectl apply -f /vagrant/${app}.yaml || {
            log "error" "Failed to apply /vagrant/${app}.yaml."
            exit 1
        }
        log "success" "Applied /vagrant/${app}.yml successfully."
    done
}

# Execute the functions
install_curl
install_k3s
wait_for_k3s
update_hosts
apply_manifests

log "success" "Provisioning completed successfully."
