all:
	@bash setup_gitlab.sh

clean:
	@if kubectl get namespace gitlab >/dev/null 2>&1; then \
		echo "$(GREEN)Namespace 'gitlab' found. Deleting all resources...$(RESET)"; \
		kubectl delete all --all -n gitlab; \
		kubectl delete namespace gitlab; \
	else \
		echo "$(GREEN)Namespace 'gitlab' not found. Skipping...$(RESET)"; \
	fi
