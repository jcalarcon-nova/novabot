# NovaBot Suggested Commands

## Terraform Operations

### Environment Setup
```bash
# Install Terraform version manager (recommended)
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc

# Install and use specific Terraform version
tfenv install 1.13.0
tfenv use 1.13.0
```

### Daily Terraform Workflow
```bash
# Navigate to Terraform directory
cd infra/terraform

# Format code
terraform fmt -recursive

# Initialize with backend
terraform init -backend-config=envs/dev/backend.hcl

# Validate configuration
terraform validate

# Plan changes
terraform plan -var-file=envs/dev/terraform.tfvars

# Apply changes (with confirmation)
terraform apply -var-file=envs/dev/terraform.tfvars

# Show current state
terraform state list
```

## Lambda Development

### TypeScript Lambda Functions
```bash
# Navigate to specific Lambda
cd lambda/zendesk_create_ticket

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests
npm test

# Package for deployment
zip -r function.zip dist/ node_modules/
```

## AWS CLI Operations

### Bedrock Agent Testing
```bash
# Test agent invocation
aws bedrock-agent-runtime invoke-agent \
  --agent-id <AGENT_ID> \
  --agent-alias-id <ALIAS_ID> \
  --session-id test-session \
  --input-text "I need help with my Mule application"
```

### Secrets Management
```bash
# Retrieve Zendesk credentials
aws secretsmanager get-secret-value \
  --secret-id zendesk-credentials \
  --query SecretString
```

### IAM Policy Testing
```bash
# Test IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn <LAMBDA_ROLE_ARN> \
  --action-names bedrock:InvokeAgent \
  --resource-arns <AGENT_ARN>
```

## Development Tools

### Git Workflow
```bash
# Standard GitHub flow
git checkout main && git pull origin main
git checkout -b feature/new-feature
# Make changes
git add . && git commit -m "feat: implement new feature"
git push origin feature/new-feature
# Create PR via GitHub web interface
```

### Project Setup
```bash
# Create project structure
mkdir -p infra/terraform/{envs/{dev,prod},modules}
mkdir -p lambda/{zendesk_create_ticket,lex_fulfillment,invoke_agent}
mkdir -p web/widget data/knowledge_base .github/workflows
```

## Testing & Validation

### Integration Testing
```bash
# Test Zendesk API endpoint
curl -X POST https://api.novabot.example.com/support/tickets \
  -H "Content-Type: application/json" \
  -d '{"requester_email": "test@example.com", "subject": "Test", "description": "Test ticket"}'

# Test web widget locally
cd web/widget && python -m http.server 8000
# Open http://localhost:8000 in browser
```

### CI/CD Pipeline
```bash
# Run locally what CI runs
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=envs/dev/terraform.tfvars
npm test  # for all Lambda functions
```

## Monitoring & Debugging

### CloudWatch Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/zendesk-create-ticket --follow

# View API Gateway logs  
aws logs tail /aws/apigateway/nova-chatbot --follow
```

### Resource Cleanup
```bash
# Destroy development environment
terraform destroy -var-file=envs/dev/terraform.tfvars

# Clean up Terraform state
terraform state rm <resource_name>  # if needed
```