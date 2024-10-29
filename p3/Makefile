GREEN=\033[32m
RESET=\033[0m

CLUSTER_NAME="ci-cluster"
POD_NAME="my-app"

# Default target when 'make' is run without arguments
all: install-dependencies setup

# Install required dependencies by running an external script
install-dependencies:
	@bash install_dependencies.sh

# Set up the k3d cluster by running an external script
setup:
	@bash setup_cluster.sh ${CLUSTER_NAME}

# Fetch information about Kubernetes resources (namespaces, pods, services, and ArgoCD apps)
infos:
	@echo "$(GREEN)Fetching Kubernetes information...$(RESET)"

	@if kubectl get namespaces >/dev/null 2>&1; then \
		echo "$(GREEN)Kubernetes namespaces:$(RESET)"; \
		kubectl get namespaces; \
	else \
		echo "$(GREEN)No namespaces found.$(RESET)"; \
	fi

	@if kubectl get pods --all-namespaces >/dev/null 2>&1; then \
		echo "$(GREEN)Kubernetes pods:$(RESET)"; \
		kubectl get pods --all-namespaces; \
	else \
		echo "$(GREEN)No pods found.$(RESET)"; \
	fi

	@if kubectl get pod ${POD_NAME} -n dev >/dev/null 2>&1; then \
		echo "$(GREEN)Kubernetes services for pod '${POD_NAME}' in namespace 'dev':$(RESET)"; \
		kubectl describe pod ${POD_NAME} -n dev; \
	else \
		echo "$(GREEN)Pod ${POD_NAME} in namespace 'dev' not found. Skipping...$(RESET)"; \
	fi

	@if command -v argocd >/dev/null 2>&1; then \
		if argocd app get ${POD_NAME} >/dev/null 2>&1; then \
			echo "$(GREEN)ArgoCD information for '${POD_NAME}':$(RESET)"; \
			argocd app get ${POD_NAME}; \
		else \
			echo "$(GREEN)ArgoCD app '${POD_NAME}' not found. Skipping...$(RESET)"; \
		fi; \
	else \
		echo "$(GREEN)ArgoCD CLI not found. Skipping ArgoCD information...$(RESET)"; \
	fi

# Clean up resources and Docker containers
clean:
	@echo "$(GREEN)Cleaning up...$(RESET)"

	@if kubectl get namespace argocd >/dev/null 2>&1; then \
		echo "$(GREEN)Namespace 'argocd' found. Deleting all resources...$(RESET)"; \
		kubectl delete all --all -n argocd; \
		kubectl delete namespace argocd; \
	else \
		echo "$(GREEN)Namespace 'argocd' not found. Skipping...$(RESET)"; \
	fi

	@if kubectl get namespace dev >/dev/null 2>&1; then \
		echo "$(GREEN)Namespace 'dev' found. Deleting all resources...$(RESET)"; \
		kubectl delete all --all -n dev; \
		kubectl delete namespace dev; \
	else \
		echo "$(GREEN)Namespace 'dev' not found. Skipping...$(RESET)"; \
	fi

	@if k3d cluster list | grep -q ${CLUSTER_NAME}; then \
		echo "$(GREEN)Cluster '${CLUSTER_NAME}' found. Deleting...$(RESET)"; \
		k3d cluster delete ${CLUSTER_NAME}; \
	else \
		echo "$(GREEN)Cluster '${CLUSTER_NAME}' not found. Skipping...$(RESET)"; \
	fi

	@if [ -n "$$(docker ps -q)" ]; then \
		echo "$(GREEN)Stopping running Docker containers...$(RESET)"; \
		docker stop $$(docker ps -q); \
	else \
		echo "$(GREEN)No running Docker containers found. Skipping...$(RESET)"; \
	fi

	@echo "$(GREEN)Pruning Docker system...$(RESET)"
	docker system prune -a --volumes -f

	@echo "$(GREEN)Clean up completed successfully.$(RESET)"

