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

# Update package index
log "info" "Updating package index..."
sudo apt-get update

install_docker() {
    if ! command -v docker > /dev/null; then
        log "info" "Installing Docker..."

        # Add Docker's official GPG key:
        sudo apt-get update
        sudo apt-get install ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources:
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
        log "success" "Docker installed successfully"
    else
        log "info" "Docker is already installed"
    fi

    # Add user to Docker group
    if ! id -nG "$USER" | grep -qw docker; then
        log "info" "Adding user to Docker group..."
        sudo usermod -aG docker "$USER"
        log "success" "User added to Docker group. Please log out and back in to apply."
    else
        log "info" "User is already in Docker group"
    fi
}

install_kubectl() {
    if ! command -v kubectl > /dev/null; then
        log "info" "Installing kubectl using snap..."
        sudo snap install kubectl --classic
        log "success" "kubectl installed successfully"
    else
        log "info" "kubectl is already installed"
    fi

}

install_k3d() {
    if ! command -v k3d > /dev/null; then
        log "info" "Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
        log "success" "k3d installed successfully"
    else
        log "info" "k3d is already installed"
    fi
}

log "info" "Installing required dependencies..."
sudo apt-get install -y apt-transport-https ca-certificates curl net-tools
install_docker
install_kubectl
install_k3d
log "success" "Dependencies installed successfully."
