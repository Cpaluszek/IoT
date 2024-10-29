#!/bin/bash
set -euo pipefail   # Exit on error, unset variables, and pipe failures

COLOR_RESET="\033[0m"
COLOR="\033[34m" # Blue

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

GITLAB_URL="gitlab.k3d.gitlab.com:8081"
GITLAB_ROOT_USER="root"
GITLAB_REPO_NAME="gitlab_cpalusze"
GITHUB_REPO_NAME="cpalusze"
GITLAB_NAMESPACE="root"
GITLAB_PSW=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 -d)
LOCAL_REPO_DIR="gitlab_cpalusze"
GITLAB_TOKEN=""

# Create .netrc file with GitLab credentials
echo "machine gitlab.k3d.gitlab.com:8081
login root
password ${GITLAB_PSW}" | sudo tee /root/.netrc > /dev/null

sudo chmod 600 /root/.netrc

log "info" "Creating GitLab project..."
curl --header "Private-Token: $GITLAB_TOKEN" -X POST "$GITLAB_URL/api/v4/projects" \
    --form "name=$GITLAB_REPO_NAME" \
    --form "visibility=public"

# Clone the newly created GitLab repository
log "info" "Cloning the GitLab repository..."
# git clone "$GITLAB_ROOT_USER:$GITLAB_PSW@$GITLAB_URL/$GITLAB_NAMESPACE/$GITLAB_REPO_NAME.git" $LOCAL_REPO_DIR
git clone "http://$GITLAB_URL/$GITLAB_NAMESPACE/$GITLAB_REPO_NAME.git" $LOCAL_REPO_DIR

# Clone the GitHub repository
log "info" "Cloning the GitHub repository..."
git clone "https://github.com/Cpaluszek/$GITHUB_REPO_NAME.git"

# Move the contents from the GitHub repository to the GitLab repository
log "info" "Moving the contents from the GitHub repository to the GitLab repository..."
mv ${GITHUB_REPO_NAME}/* ${LOCAL_REPO_DIR}/
rm -rf ${GITHUB_REPO_NAME}

log "info" "Directory contents:"
ls -la ${LOCAL_REPO_DIR}

# Navigate to the local GitLab repository directory
cd ${LOCAL_REPO_DIR}

# Initialize and push the changes to GitLab
log "info" "Pushing local repository to GitLab..."
git add .
git commit -m "Initial commit with Kubernetes manifests"
git push --set-upstream origin main

log "success" "GitLab project initialized and pushed successfully."

log "info" "Update argocd app settings"
argocd app set my-app --grpc-web --repo "http://gitlab-webservice-default.gitlab.svc:8181/$GITLAB_ROOT_USER/$GITLAB_REPO_NAME.git/"
