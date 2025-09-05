#!/bin/bash

# NovaBot Knowledge Base Deployment Script
# This script uploads knowledge base files to S3 and syncs with Bedrock Knowledge Base

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KNOWLEDGE_BASE_DIR="data/knowledge_base"
TERRAFORM_DIR="infra/terraform/envs/dev"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if knowledge base directory exists
    if [[ ! -d "$KNOWLEDGE_BASE_DIR" ]]; then
        log_error "Knowledge base directory not found: $KNOWLEDGE_BASE_DIR"
        exit 1
    fi
    
    # Check if terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    log_success "All prerequisites check passed"
}

# Get terraform outputs
get_terraform_outputs() {
    log_info "Getting Terraform outputs..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if terraform state exists
    if [[ ! -f "terraform.tfstate" ]]; then
        log_error "Terraform state not found. Please run 'terraform apply' first."
        exit 1
    fi
    
    # Get S3 bucket name
    S3_BUCKET=$(terraform output -raw knowledge_base_s3_bucket_name 2>/dev/null || echo "")
    if [[ -z "$S3_BUCKET" ]]; then
        log_error "Could not get S3 bucket name from Terraform outputs"
        exit 1
    fi
    
    # Get Knowledge Base ID (optional, might not exist yet)
    KNOWLEDGE_BASE_ID=$(terraform output -raw knowledge_base_id 2>/dev/null || echo "")
    
    # Get Data Source ID (optional, might not exist yet)
    DATA_SOURCE_ID=$(terraform output -raw knowledge_base_data_source_id 2>/dev/null || echo "")
    
    cd - > /dev/null
    
    log_success "Retrieved Terraform outputs"
    log_info "S3 Bucket: $S3_BUCKET"
    if [[ -n "$KNOWLEDGE_BASE_ID" ]]; then
        log_info "Knowledge Base ID: $KNOWLEDGE_BASE_ID"
    fi
    if [[ -n "$DATA_SOURCE_ID" ]]; then
        log_info "Data Source ID: $DATA_SOURCE_ID"
    fi
}

# Validate knowledge base files
validate_knowledge_base_files() {
    log_info "Validating knowledge base files..."
    
    local csv_count=0
    for file in "$KNOWLEDGE_BASE_DIR"/*.csv; do
        if [[ -f "$file" ]]; then
            csv_count=$((csv_count + 1))
            log_info "Found CSV file: $(basename "$file")"
            
            # Basic CSV validation - check if file has header
            if [[ ! -s "$file" ]]; then
                log_error "CSV file is empty: $file"
                exit 1
            fi
            
            # Check if file has proper header
            header=$(head -n 1 "$file")
            if [[ ! "$header" =~ ^question,answer,category,tags,priority ]]; then
                log_warning "CSV file might not have proper header format: $file"
            fi
        fi
    done
    
    if [[ $csv_count -eq 0 ]]; then
        log_error "No CSV files found in $KNOWLEDGE_BASE_DIR"
        exit 1
    fi
    
    log_success "Found $csv_count CSV files to upload"
}

# Upload files to S3
upload_to_s3() {
    log_info "Uploading knowledge base files to S3..."
    
    # Sync the entire knowledge base directory
    aws s3 sync "$KNOWLEDGE_BASE_DIR/" "s3://$S3_BUCKET/knowledge_base/" \
        --exclude "*.md" \
        --exclude ".*" \
        --delete
    
    if [[ $? -eq 0 ]]; then
        log_success "Successfully uploaded files to s3://$S3_BUCKET/knowledge_base/"
    else
        log_error "Failed to upload files to S3"
        exit 1
    fi
    
    # List uploaded files for verification
    log_info "Uploaded files:"
    aws s3 ls "s3://$S3_BUCKET/knowledge_base/" --human-readable --summarize
}

# Trigger Bedrock Knowledge Base sync
sync_knowledge_base() {
    if [[ -z "$KNOWLEDGE_BASE_ID" ]] || [[ -z "$DATA_SOURCE_ID" ]]; then
        log_warning "Knowledge Base ID or Data Source ID not available. Skipping sync."
        log_info "You can manually trigger sync later using:"
        log_info "aws bedrock-agent start-ingestion-job --knowledge-base-id <KB_ID> --data-source-id <DS_ID>"
        return 0
    fi
    
    log_info "Triggering Bedrock Knowledge Base sync..."
    
    # Start ingestion job
    JOB_ID=$(aws bedrock-agent start-ingestion-job \
        --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
        --data-source-id "$DATA_SOURCE_ID" \
        --query 'ingestionJob.ingestionJobId' \
        --output text)
    
    if [[ $? -eq 0 ]] && [[ -n "$JOB_ID" ]]; then
        log_success "Started ingestion job: $JOB_ID"
        log_info "You can monitor the job status in the AWS Console or using:"
        log_info "aws bedrock-agent get-ingestion-job --knowledge-base-id $KNOWLEDGE_BASE_ID --data-source-id $DATA_SOURCE_ID --ingestion-job-id $JOB_ID"
    else
        log_error "Failed to start ingestion job"
        exit 1
    fi
}

# Main deployment function
deploy() {
    log_info "Starting NovaBot Knowledge Base deployment..."
    echo
    
    check_prerequisites
    echo
    
    get_terraform_outputs
    echo
    
    validate_knowledge_base_files
    echo
    
    upload_to_s3
    echo
    
    sync_knowledge_base
    echo
    
    log_success "Deployment completed successfully!"
    log_info "Knowledge base files have been uploaded and sync initiated."
    log_info "Check the AWS Bedrock console to monitor ingestion progress."
}

# Help function
show_help() {
    cat << EOF
NovaBot Knowledge Base Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --validate-only Only validate files without deploying
    --dry-run          Show what would be uploaded without actually uploading

EXAMPLES:
    $0                  # Deploy knowledge base
    $0 --validate-only  # Only validate CSV files
    $0 --dry-run        # Show deployment plan without executing

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - Terraform infrastructure deployed
    - Knowledge base CSV files in $KNOWLEDGE_BASE_DIR

EOF
}

# Parse command line arguments
VALIDATE_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute based on options
if [[ "$VALIDATE_ONLY" == true ]]; then
    log_info "Running validation only..."
    check_prerequisites
    validate_knowledge_base_files
    log_success "Validation completed successfully!"
elif [[ "$DRY_RUN" == true ]]; then
    log_info "Running dry-run..."
    check_prerequisites
    get_terraform_outputs
    validate_knowledge_base_files
    log_info "Dry-run completed. Files would be uploaded to: s3://$S3_BUCKET/knowledge_base/"
else
    deploy
fi