.PHONY: help init plan apply destroy fmt validate clean test package deploy

# Default target
help:
	@echo "Available targets:"
	@echo "  help       - Show this help message"
	@echo "  init       - Initialize Terraform"
	@echo "  plan       - Run Terraform plan"
	@echo "  apply      - Apply Terraform changes"
	@echo "  destroy    - Destroy Terraform resources"
	@echo "  fmt        - Format Terraform files"
	@echo "  validate   - Validate Terraform configuration"
	@echo "  clean      - Clean temporary files"
	@echo "  test       - Run all tests"
	@echo "  package    - Package Lambda functions"
	@echo "  deploy     - Deploy everything"

# Environment variable defaults
ENV ?= dev
TF_DIR := infra/terraform

# Terraform operations
init:
	cd $(TF_DIR) && terraform init -backend-config=envs/$(ENV)/backend.hcl

plan:
	cd $(TF_DIR) && terraform plan -var-file=envs/$(ENV)/terraform.tfvars

apply:
	cd $(TF_DIR) && terraform apply -var-file=envs/$(ENV)/terraform.tfvars

destroy:
	cd $(TF_DIR) && terraform destroy -var-file=envs/$(ENV)/terraform.tfvars

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate: fmt
	cd $(TF_DIR) && terraform validate

# Lambda operations  
test:
	@for dir in lambda/*/; do \
		if [ -f "$$dir/package.json" ]; then \
			echo "Testing $$dir"; \
			cd "$$dir" && npm test && cd ../..; \
		fi; \
	done

package:
	@for dir in lambda/*/; do \
		if [ -f "$$dir/package.json" ]; then \
			echo "Packaging $$dir"; \
			cd "$$dir" && npm run build && zip -r function.zip dist/ node_modules/ && cd ../..; \
		fi; \
	done

# Cleanup
clean:
	find . -name "*.zip" -delete
	find . -name "dist" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
	cd $(TF_DIR) && rm -rf .terraform/

# Full deployment
deploy: validate package apply
	@echo "Deployment complete!"

# Development setup
setup:
	@echo "Setting up development environment..."
	@for dir in lambda/*/; do \
		if [ -f "$$dir/package.json" ]; then \
			echo "Installing dependencies for $$dir"; \
			cd "$$dir" && npm install && cd ../..; \
		fi; \
	done
	@echo "Development environment ready!"