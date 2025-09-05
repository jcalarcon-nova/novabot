# Secrets Manager - AWS 7-Day Retention Solution

## Problem

AWS Secrets Manager has a 7-day retention period for deleted secrets. When you destroy a Terraform stack and recreate it, the secret creation fails because a secret with the same name is still in "pending deletion" state.

## Solution Overview

This implementation handles the Secrets Manager retention issue by:

1. **Standard Creation**: Secrets are created normally with `recovery_window_in_days = 0`
2. **Lifecycle Management**: Uses `ignore_changes` to prevent unnecessary recreation
3. **Import Support**: Provides scripts to import existing secrets when needed

## Key Features

### 1. Immediate Deletion Support
```hcl
resource "aws_secretsmanager_secret" "zendesk_credentials" {
  name = "${var.project_name}-${var.environment}-zendesk-credentials"
  
  # Set recovery window to 0 for immediate deletion
  recovery_window_in_days = 0
  
  lifecycle {
    ignore_changes = [recovery_window_in_days]
  }
}
```

### 2. Content Protection
```hcl
resource "aws_secretsmanager_secret_version" "zendesk_credentials_version" {
  secret_id     = aws_secretsmanager_secret.zendesk_credentials.id
  secret_string = jsonencode({
    # Placeholder values - update manually after deployment
    email     = "PLACEHOLDER_EMAIL"
    api_token = "PLACEHOLDER_TOKEN"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

## Usage Scenarios

### Fresh Deployment (No Existing Secrets)
```bash
cd infra/terraform/envs/dev
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

The secret will be created with placeholder values. Update the secret manually:
```bash
aws secretsmanager update-secret --secret-id novabot-dev-zendesk-credentials \\
  --secret-string '{"email":"your-email@domain.com","api_token":"your-api-token"}'
```

### Deployment After Stack Destruction

If you destroyed the stack and secrets are in deletion state:

#### Option 1: Force Delete (Immediate)
```bash
aws secretsmanager delete-secret --secret-id novabot-dev-zendesk-credentials --force-delete-without-recovery
```

Then run normal deployment:
```bash
terraform apply
```

#### Option 2: Import Existing Secret
If the secret already exists but not in Terraform state:
```bash
cd infra/terraform/envs/dev
./scripts/import_existing_secret.sh dev
terraform plan  # Should show no changes
```

### Re-deployment (Secret Already Managed)
```bash
cd infra/terraform/envs/dev
terraform plan    # Should show no secret changes
terraform apply
```

## Scripts Provided

### `scripts/import_existing_secret.sh`
- Automatically detects existing secrets
- Imports them into Terraform state
- Handles both secret and secret version

Usage:
```bash
./scripts/import_existing_secret.sh dev   # For dev environment
./scripts/import_existing_secret.sh prod  # For prod environment
```

## Best Practices

### 1. Secret Content Management
- ✅ **Never commit real credentials** to version control
- ✅ **Use placeholder values** in Terraform
- ✅ **Update secrets manually** after deployment using AWS CLI or Console
- ✅ **Use `ignore_changes`** to prevent Terraform from overwriting manual updates

### 2. Environment Separation
- ✅ **Separate secrets per environment**: `novabot-dev-*`, `novabot-prod-*`
- ✅ **Different AWS accounts** for prod/dev (recommended)
- ✅ **Environment-specific values** in each secret

### 3. Deployment Workflow
1. **Initial Setup**: Deploy infrastructure, then update secrets manually
2. **Regular Deployments**: Secrets are ignored, only infrastructure changes apply
3. **Secret Updates**: Use AWS CLI/Console, never through Terraform
4. **Troubleshooting**: Use import script if state gets out of sync

## Troubleshooting

### Error: Secret already exists
```bash
# Check if secret is in deletion state
aws secretsmanager describe-secret --secret-id novabot-dev-zendesk-credentials

# Force delete if needed
aws secretsmanager delete-secret --secret-id novabot-dev-zendesk-credentials --force-delete-without-recovery

# Or import if it should be managed
./scripts/import_existing_secret.sh dev
```

### Error: Secret not found in state
```bash
# Import existing secret
./scripts/import_existing_secret.sh dev
```

### Error: Terraform wants to recreate secret
This usually means the lifecycle rules aren't working. Check:
1. `ignore_changes` is properly configured
2. Secret name matches exactly
3. No conflicting resource definitions

## Security Considerations

1. **KMS Encryption**: All secrets are encrypted with project-specific KMS key
2. **IAM Permissions**: Lambda functions have minimal required permissions
3. **Recovery Window**: Set to 0 for development, consider longer for production
4. **Access Logging**: CloudTrail logs all secret access attempts

## Production Recommendations

For production environments:
- Use longer `recovery_window_in_days` (7-30 days)
- Implement secret rotation
- Use AWS Secrets Manager automatic rotation
- Monitor secret access with CloudWatch
- Use separate AWS accounts for isolation