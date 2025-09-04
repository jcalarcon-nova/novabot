#!/bin/bash

# NovaBot Infrastructure Validation Script
# This script validates that all Terraform modules and AWS resources are properly configured

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infra/terraform"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

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

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Running test: $test_name"
    
    if eval "$test_command"; then
        log_success "✓ $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ $test_name"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Verify prerequisites
test_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        return 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        return 1
    fi
    
    # Check Node.js (for Lambda functions)
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

# Test 2: Validate Terraform syntax
test_terraform_syntax() {
    log_info "Validating Terraform syntax..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform (required for validation)
    if ! terraform init -backend=false &> /dev/null; then
        log_error "Terraform init failed"
        return 1
    fi
    
    # Validate syntax
    if ! terraform validate; then
        log_error "Terraform validation failed"
        return 1
    fi
    
    log_success "Terraform syntax is valid"
    return 0
}

# Test 3: Check Terraform plan
test_terraform_plan() {
    log_info "Checking Terraform plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Try to create a plan without applying
    if terraform plan -var-file="envs/${ENVIRONMENT}/terraform.tfvars" -out=validation.tfplan &> /dev/null; then
        rm -f validation.tfplan
        log_success "Terraform plan is valid"
        return 0
    else
        log_error "Terraform plan failed"
        return 1
    fi
}

# Test 4: Validate Lambda function dependencies
test_lambda_dependencies() {
    log_info "Validating Lambda function dependencies..."
    
    local lambda_dirs=(
        "${PROJECT_ROOT}/lambda/zendesk_create_ticket"
        "${PROJECT_ROOT}/lambda/lex_fulfillment"
        "${PROJECT_ROOT}/lambda/invoke_agent"
    )
    
    for dir in "${lambda_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            cd "$dir"
            
            # Check package.json exists
            if [[ ! -f "package.json" ]]; then
                log_error "package.json not found in $dir"
                return 1
            fi
            
            # Check if dependencies can be installed
            if ! npm install --dry-run &> /dev/null; then
                log_error "npm install failed for $dir"
                return 1
            fi
            
            log_success "Lambda dependencies valid for $(basename "$dir")"
        else
            log_warning "Lambda directory not found: $dir"
        fi
    done
    
    return 0
}

# Test 5: Validate TypeScript compilation
test_typescript_compilation() {
    log_info "Validating TypeScript compilation..."
    
    local lambda_dirs=(
        "${PROJECT_ROOT}/lambda/zendesk_create_ticket"
        "${PROJECT_ROOT}/lambda/lex_fulfillment"
        "${PROJECT_ROOT}/lambda/invoke_agent"
    )
    
    for dir in "${lambda_dirs[@]}"; do
        if [[ -d "$dir" && -f "$dir/tsconfig.json" ]]; then
            cd "$dir"
            
            # Install dependencies first
            if ! npm install &> /dev/null; then
                log_error "npm install failed for $dir"
                return 1
            fi
            
            # Compile TypeScript
            if ! npm run build &> /dev/null; then
                log_error "TypeScript compilation failed for $dir"
                return 1
            fi
            
            log_success "TypeScript compilation successful for $(basename "$dir")"
        fi
    done
    
    return 0
}

# Test 6: Validate JSON/YAML files
test_config_files() {
    log_info "Validating configuration files..."
    
    # Check OpenAPI schema
    local openapi_file="${PROJECT_ROOT}/infra/terraform/modules/bedrock_agent/openapi/zendesk.yaml"
    if [[ -f "$openapi_file" ]]; then
        # Basic YAML syntax check
        if ! python3 -c "import yaml; yaml.safe_load(open('$openapi_file'))" 2>/dev/null; then
            log_error "Invalid YAML syntax in OpenAPI schema"
            return 1
        fi
        log_success "OpenAPI schema is valid YAML"
    fi
    
    # Check package.json files
    find "$PROJECT_ROOT" -name "package.json" -type f | while read -r package_file; do
        if ! python3 -c "import json; json.load(open('$package_file'))" 2>/dev/null; then
            log_error "Invalid JSON syntax in $package_file"
            return 1
        fi
    done
    
    log_success "Configuration files are valid"
    return 0
}

# Test 7: Check CSV data files
test_csv_data() {
    log_info "Validating CSV data files..."
    
    local csv_dir="${PROJECT_ROOT}/data/knowledge_base"
    if [[ -d "$csv_dir" ]]; then
        local csv_files=("$csv_dir"/*.csv)
        
        for csv_file in "${csv_files[@]}"; do
            if [[ -f "$csv_file" ]]; then
                # Check if file has content and proper CSV structure
                if [[ $(wc -l < "$csv_file") -lt 2 ]]; then
                    log_error "CSV file $csv_file has insufficient content"
                    return 1
                fi
                
                # Check for consistent column count (basic validation)
                local first_line_columns
                first_line_columns=$(head -n1 "$csv_file" | tr ',' '\n' | wc -l)
                
                if ! awk -F',' -v cols="$first_line_columns" 'NR>1 && NF!=cols {exit 1}' "$csv_file"; then
                    log_error "CSV file $csv_file has inconsistent column count"
                    return 1
                fi
                
                log_success "CSV file $(basename "$csv_file") is valid"
            fi
        done
    else
        log_warning "CSV data directory not found"
    fi
    
    return 0
}

# Test 8: Validate GitHub Actions workflows
test_github_workflows() {
    log_info "Validating GitHub Actions workflows..."
    
    local workflow_dir="${PROJECT_ROOT}/.github/workflows"
    if [[ -d "$workflow_dir" ]]; then
        local workflow_files=("$workflow_dir"/*.yml "$workflow_dir"/*.yaml)
        
        for workflow_file in "${workflow_files[@]}"; do
            if [[ -f "$workflow_file" ]]; then
                # Basic YAML syntax check
                if ! python3 -c "import yaml; yaml.safe_load(open('$workflow_file'))" 2>/dev/null; then
                    log_error "Invalid YAML syntax in $(basename "$workflow_file")"
                    return 1
                fi
                
                log_success "GitHub workflow $(basename "$workflow_file") is valid"
            fi
        done
    else
        log_warning "GitHub workflows directory not found"
    fi
    
    return 0
}

# Test 9: Check web widget files
test_web_widget() {
    log_info "Validating web widget files..."
    
    local widget_dir="${PROJECT_ROOT}/web/widget"
    if [[ -d "$widget_dir" ]]; then
        # Check required files exist
        local required_files=("widget.js" "widget.css")
        for file in "${required_files[@]}"; do
            if [[ ! -f "$widget_dir/$file" ]]; then
                log_error "Required widget file not found: $file"
                return 1
            fi
        done
        
        # Check JavaScript syntax (basic)
        if command -v node &> /dev/null; then
            if ! node -c "$widget_dir/widget.js"; then
                log_error "JavaScript syntax error in widget.js"
                return 1
            fi
        fi
        
        log_success "Web widget files are valid"
    else
        log_warning "Web widget directory not found"
    fi
    
    return 0
}

# Test 10: Validate Bedrock model availability
test_bedrock_models() {
    log_info "Checking Bedrock model availability..."
    
    # Check Claude 3.5 Sonnet availability
    if aws bedrock list-foundation-models --region "$AWS_REGION" --query 'modelSummaries[?modelId==`anthropic.claude-3-5-sonnet-20241022-v2:0`]' --output text | grep -q "anthropic"; then
        log_success "Claude 3.5 Sonnet model is available"
    else
        log_warning "Claude 3.5 Sonnet model may not be available in $AWS_REGION"
    fi
    
    # Check Titan Embeddings availability
    if aws bedrock list-foundation-models --region "$AWS_REGION" --query 'modelSummaries[?modelId==`amazon.titan-embed-text-v1`]' --output text | grep -q "amazon"; then
        log_success "Titan Embeddings model is available"
    else
        log_warning "Titan Embeddings model may not be available in $AWS_REGION"
    fi
    
    return 0
}

# Main execution
main() {
    log_info "Starting NovaBot infrastructure validation..."
    log_info "Project root: $PROJECT_ROOT"
    log_info "Environment: $ENVIRONMENT"
    log_info "AWS Region: $AWS_REGION"
    echo ""
    
    # Run all tests
    run_test "Prerequisites Check" "test_prerequisites"
    run_test "Terraform Syntax Validation" "test_terraform_syntax"
    run_test "Terraform Plan Check" "test_terraform_plan"
    run_test "Lambda Dependencies" "test_lambda_dependencies"
    run_test "TypeScript Compilation" "test_typescript_compilation"
    run_test "Configuration Files" "test_config_files"
    run_test "CSV Data Files" "test_csv_data"
    run_test "GitHub Workflows" "test_github_workflows"
    run_test "Web Widget Files" "test_web_widget"
    run_test "Bedrock Models" "test_bedrock_models"
    
    # Summary
    echo ""
    log_info "=== Validation Summary ==="
    log_success "Tests passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Tests failed: $TESTS_FAILED"
        echo ""
        log_error "Failed tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "  - $failed_test"
        done
        echo ""
        log_error "Infrastructure validation failed!"
        exit 1
    else
        echo ""
        log_success "🎉 All infrastructure validation tests passed!"
        log_success "NovaBot is ready for deployment!"
        exit 0
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi