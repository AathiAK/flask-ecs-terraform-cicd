.PHONY: help init plan apply destroy build push deploy test logs clean

GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m

help: ## Show this help
	@echo "$(GREEN)Flask ECS EC2 Demo Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

init: ## Initialize Terraform
	@echo "$(GREEN)Initializing Terraform...$(NC)"
	cd terraform && terraform init

plan: ## Plan Terraform changes
	@echo "$(GREEN)Planning Terraform...$(NC)"
	cd terraform && terraform plan

apply: ## Apply Terraform (create infrastructure)
	@echo "$(GREEN)Creating infrastructure...$(NC)"
	cd terraform && terraform apply -auto-approve

build: ## Build Docker image
	@echo "$(GREEN)Building Docker image...$(NC)"
	cd docker && docker build -t flask-demo:latest .

push: ## Push image to ECR
	@echo "$(GREEN)Pushing to ECR...$(NC)"
	bash scripts/build-and-push.sh

deploy: ## Deploy to ECS
	@echo "$(GREEN)Deploying to ECS...$(NC)"
	bash scripts/deploy-ecs.sh

test: ## Test application
	@echo "$(GREEN)Testing application...$(NC)"
	bash scripts/get-instance-ips.sh

logs: ## View CloudWatch logs
	@echo "$(GREEN)Viewing logs...$(NC)"
	aws logs tail /ecs/flask-demo --follow

status: ## Check ECS service status
	@echo "$(GREEN)ECS Service Status:$(NC)"
	@aws ecs describe-services \
		--cluster flask-demo-cluster \
		--services flask-demo-service \
		--query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
		--output table

tasks: ## List ECS tasks
	@echo "$(GREEN)ECS Tasks:$(NC)"
	@aws ecs list-tasks --cluster flask-demo-cluster

instances: ## Show EC2 instances
	@echo "$(GREEN)EC2 Instances:$(NC)"
	@aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=flask-demo-ecs-instance" \
				  "Name=instance-state-name,Values=running" \
		--query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress]' \
		--output table

destroy: ## Destroy all resources
	@echo "$(GREEN)Destroying infrastructure...$(NC)"
	@aws ecs update-service --cluster flask-demo-cluster --service flask-demo-service --desired-count 0 || true
	@sleep 30
	cd terraform && terraform destroy -auto-approve

clean: ## Clean local Docker images
	@echo "$(GREEN)Cleaning Docker images...$(NC)"
	docker rmi flask-demo:latest || true

# Combined workflows
full-deploy: apply push deploy test ## Complete deployment (infrastructure + app)
	@echo "$(GREEN)✅ Full deployment complete!$(NC)"

update-app: build push deploy ## Update application code
	@echo "$(GREEN)✅ Application updated!$(NC)"

.DEFAULT_GOAL := help
