#!/bin/bash

# Script to import existing Secrets Manager secret into Terraform state
# Usage: ./import_existing_secret.sh [environment]
# Example: ./import_existing_secret.sh dev

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME="novabot"
SECRET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-zendesk-credentials"

echo "Importing existing secret: $SECRET_NAME"

# Check if secret exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" >/dev/null 2>&1; then
    echo "Secret exists, importing into Terraform state..."
    
    # Import the secret
    terraform import module.iam.aws_secretsmanager_secret.zendesk_credentials "$SECRET_NAME"
    
    # Check if secret version exists and import it
    SECRET_VERSION_ID=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query 'VersionIdsToStages.keys(@)[0]' --output text)
    if [ "$SECRET_VERSION_ID" != "None" ] && [ -n "$SECRET_VERSION_ID" ]; then
        echo "Importing secret version: $SECRET_VERSION_ID"
        terraform import "module.iam.aws_secretsmanager_secret_version.zendesk_credentials_version" "${SECRET_NAME}|${SECRET_VERSION_ID}"
    fi
    
    echo "Import completed successfully!"
else
    echo "Secret $SECRET_NAME does not exist. No import needed."
fi