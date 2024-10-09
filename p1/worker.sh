#!/bin/bash

set -euo pipefail   # Exit on error, unset variables, and pipe failures

SERVER_IP=$1
WORKER_IP=$2

sudo apt-get update

# Install curl
if ! command -v curl &> /dev/null
then
    echo "curl could not be found"
    echo "Installing curl..."
    sudo apt-get install -y curl
fi

# Retrieve k3s token from the master node
if [ ! -f /vagrant/node-token ]; then
    echo "Error: Token file not found in /vagrant/"
    exit 1
fi
K3S_TOKEN=$(cat /vagrant/node-token)

# Install k3s
if command -v k3s >/dev/null 2>&1; then
    echo -e "K3s is already installed"
else
    echo -e "K3s is not installed. Proceeding with installation..."

    # K3s configuration
    # https://docs.k3s.io/cli/server
    export INSTALL_K3S_EXEC="agent --server https://$SERVER_IP:6443 --token $K3S_TOKEN --node-ip=$WORKER_IP"

    # Install K3s
    if curl -sfL https://get.k3s.io | sh -; then
        echo -e "K3s AGENT installation SUCCEEDED"
    else
        echo -e "K3s AGENT installation FAILED"
    fi
fi

