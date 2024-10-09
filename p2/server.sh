#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

sudo apt-get update

install_curl() {
    if ! command -v curl &> /dev/null
    then
        echo "curl could not be found"
        echo "Installing curl..."
        sudo apt-get install -y curl
    fi
}

install_k3s() {
    if command -v k3s >/dev/null 2>&1; then
        echo -e "K3s is already installed"
    else
        echo -e "K3s is not installed. Proceeding with installation..."

        # K3s configuration
        # https://docs.k3s.io/cli/server
        export INSTALL_K3S_EXEC="--write-kubeconfig-mode=644"

        # Install K3s
        if curl -sfL https://get.k3s.io | sh -; then
            echo -e "K3s MASTER installation SUCCEEDED"
        else
            echo -e "K3s MASTER installation FAILED"
        fi
    fi
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
}

wait_for_k3s() {
    TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
    MAX_WAIT=60
    WAIT_INTERVAL=5
    ELAPSED_TIME=0

    # Wait for the token file to be created
    while [ ! -f "$TOKEN_FILE" ]; do
        if [ $ELAPSED_TIME -ge $MAX_WAIT ]; then
            echo "Error: Token file was not found after waiting $MAX_WAIT seconds."
            exit 1
        fi

        echo "Waiting for the token file to be created... ($ELAPSED_TIME seconds elapsed)"
        sleep $WAIT_INTERVAL
        ELAPSED_TIME=$((ELAPSED_TIME + WAIT_INTERVAL))
    done
    echo "K3s MASTER is running"
}

install_curl
install_k3s
wait_for_k3s

