#!/bin/bash

# NovaBot Complete System Integration Verification
# This script performs end-to-end verification of the entire NovaBot system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infra/terraform"
ENVIRONMENT="${ENVIRONMENT:-dev}"
INTEGRATION_TEST_SESSION="integration-test-$(date +%s)"

# Verification results tracking
VERIFICATION_RESULTS=()
OVERALL_SUCCESS=true
CRITICAL_FAILURES=()

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

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
    CRITICAL_FAILURES+=("$1")
    OVERALL_SUCCESS=false
}

log_header() {
    echo ""
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN} $1${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo ""
}

# Run verification step
verify_component() {
    local component_name="$1"
    local verification_function="$2"
    local is_critical="${3:-false}"
    
    log_info "Verifying: $component_name"
    
    local start_time
    start_time=$(date +%s%3N)
    
    if eval "$verification_function"; then
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        log_success "✓ $component_name (${duration}ms)"
        VERIFICATION_RESULTS+=("PASS|$component_name|${duration}ms")
        return 0
    else
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        if [[ "$is_critical" == "true" ]]; then
            log_critical "✗ $component_name (${duration}ms) - CRITICAL FAILURE"
        else
            log_error "✗ $component_name (${duration}ms)"
            OVERALL_SUCCESS=false
        fi
        
        VERIFICATION_RESULTS+=("FAIL|$component_name|${duration}ms")
        return 1
    fi
}

# 1. Verify Terraform state and outputs
verify_terraform_deployment() {
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform state exists
    if [[ ! -f "terraform.tfstate" && ! -f ".terraform/terraform.tfstate" ]]; then
        log_error "Terraform state not found - system may not be deployed"
        return 1
    fi
    
    # Get required outputs
    local api_url
    local bedrock_agent_id
    local knowledge_base_bucket
    
    api_url=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
    bedrock_agent_id=$(terraform output -raw bedrock_agent_id 2>/dev/null || echo "")
    knowledge_base_bucket=$(terraform output -raw knowledge_base_bucket_name 2>/dev/null || echo "")
    
    if [[ -z "$api_url" ]]; then
        log_error "API Gateway URL not found in Terraform outputs"
        return 1
    fi
    
    if [[ -z "$bedrock_agent_id" ]]; then
        log_error "Bedrock Agent ID not found in Terraform outputs"
        return 1
    fi
    
    if [[ -z "$knowledge_base_bucket" ]]; then
        log_error "Knowledge Base S3 bucket not found in Terraform outputs"
        return 1
    fi
    
    # Export for use by other functions
    export SYSTEM_API_URL="$api_url"
    export SYSTEM_BEDROCK_AGENT_ID="$bedrock_agent_id"
    export SYSTEM_KB_BUCKET="$knowledge_base_bucket"
    
    log_info "System endpoints discovered:"
    log_info "  API Gateway: $api_url"
    log_info "  Bedrock Agent: $bedrock_agent_id"
    log_info "  KB S3 Bucket: $knowledge_base_bucket"
    
    return 0
}

# 2. Verify AWS services are accessible
verify_aws_services() {
    # Check Bedrock service access
    if ! aws bedrock list-foundation-models --region "${AWS_REGION:-us-east-1}" --query 'modelSummaries[0]' &>/dev/null; then
        log_error "Cannot access AWS Bedrock service"
        return 1
    fi
    
    # Check S3 bucket exists and is accessible
    if ! aws s3 ls "s3://$SYSTEM_KB_BUCKET/" &>/dev/null; then
        log_error "Cannot access Knowledge Base S3 bucket: $SYSTEM_KB_BUCKET"
        return 1
    fi
    
    # Check Lambda functions exist
    local lambda_functions=("novabot-invoke-agent-$ENVIRONMENT" "novabot-zendesk-create-ticket-$ENVIRONMENT")
    for func in "${lambda_functions[@]}"; do
        if ! aws lambda get-function --function-name "$func" &>/dev/null; then
            log_error "Lambda function not found: $func"
            return 1
        fi
    done
    
    return 0
}

# 3. Verify Bedrock Agent functionality
verify_bedrock_agent() {
    log_info "Testing Bedrock Agent with simple query..."
    
    # Create a temporary file for the response
    local response_file
    response_file=$(mktemp)
    
    # Test the agent with a simple query
    if aws bedrock-agent-runtime invoke-agent \
        --agent-id "$SYSTEM_BEDROCK_AGENT_ID" \
        --agent-alias-id "TSTALIASID" \
        --session-id "$INTEGRATION_TEST_SESSION" \
        --input-text "Hello, can you help me?" \
        "$response_file" &>/dev/null; then
        
        # Check if response contains expected content
        if [[ -s "$response_file" ]]; then
            log_info "Bedrock Agent responded successfully"
            rm -f "$response_file"
            return 0
        else
            log_error "Bedrock Agent response was empty"
            rm -f "$response_file"
            return 1
        fi
    else
        log_error "Failed to invoke Bedrock Agent"
        rm -f "$response_file"
        return 1
    fi
}

# 4. Verify Knowledge Base integration
verify_knowledge_base_integration() {
    # Check if knowledge base has content
    local file_count
    file_count=$(aws s3 ls "s3://$SYSTEM_KB_BUCKET/" --recursive | wc -l)
    
    if [[ $file_count -eq 0 ]]; then
        log_warning "Knowledge Base S3 bucket is empty - uploading sample data"
        
        # Upload sample data if it exists
        if [[ -d "$PROJECT_ROOT/data/knowledge_base" ]]; then
            aws s3 cp "$PROJECT_ROOT/data/knowledge_base/" "s3://$SYSTEM_KB_BUCKET/" --recursive
            log_info "Sample knowledge base data uploaded"
        else
            log_error "No knowledge base data found to upload"
            return 1
        fi
    else
        log_info "Knowledge Base contains $file_count files"
    fi
    
    # Test agent with knowledge-based query
    log_info "Testing knowledge base integration..."
    
    local response_file
    response_file=$(mktemp)
    
    if aws bedrock-agent-runtime invoke-agent \
        --agent-id "$SYSTEM_BEDROCK_AGENT_ID" \
        --agent-alias-id "TSTALIASID" \
        --session-id "$INTEGRATION_TEST_SESSION-kb" \
        --input-text "How do I reset my password?" \
        "$response_file" &>/dev/null; then
        
        if [[ -s "$response_file" ]]; then
            log_info "Knowledge base query successful"
            rm -f "$response_file"
            return 0
        else
            log_error "Knowledge base query returned empty response"
            rm -f "$response_file"
            return 1
        fi
    else
        log_error "Knowledge base query failed"
        rm -f "$response_file"
        return 1
    fi
}

# 5. Verify API Gateway endpoints
verify_api_endpoints() {
    log_info "Testing API Gateway endpoints..."
    
    # Test health endpoint
    local health_response
    health_response=$(curl -s -w "%{http_code}" -o /tmp/health_response.json "$SYSTEM_API_URL/health" || echo "000")
    
    if [[ "$health_response" == "200" ]]; then
        log_info "Health endpoint responding correctly"
    else
        log_error "Health endpoint failed with status: $health_response"
        return 1
    fi
    
    # Test chat endpoint
    local chat_response
    chat_response=$(curl -s -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -H "Origin: https://example.com" \
        -d '{"message": "Integration test message"}' \
        -o /tmp/chat_response.json \
        "$SYSTEM_API_URL/chat" || echo "000")
    
    if [[ "$chat_response" == "200" ]]; then
        # Check if response contains expected fields
        if jq -e '.response' /tmp/chat_response.json &>/dev/null; then
            log_info "Chat endpoint responding with valid JSON"
        else
            log_error "Chat endpoint response missing expected fields"
            return 1
        fi
    else
        log_error "Chat endpoint failed with status: $chat_response"
        return 1
    fi
    
    # Cleanup temp files
    rm -f /tmp/health_response.json /tmp/chat_response.json
    
    return 0
}

# 6. Verify Lambda function integrations
verify_lambda_integrations() {
    log_info "Testing Lambda function integrations..."
    
    # Test invoke-agent Lambda directly
    local invoke_response
    invoke_response=$(aws lambda invoke \
        --function-name "novabot-invoke-agent-$ENVIRONMENT" \
        --payload '{"body": "{\"message\": \"Test message\"}", "headers": {}}' \
        /tmp/invoke_response.json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        # Check response status code
        local status_code
        status_code=$(jq -r '.statusCode // 500' /tmp/invoke_response.json 2>/dev/null || echo "500")
        
        if [[ "$status_code" == "200" ]]; then
            log_info "Invoke-agent Lambda responding correctly"
        else
            log_error "Invoke-agent Lambda returned status: $status_code"
            return 1
        fi
    else
        log_error "Failed to invoke invoke-agent Lambda: $invoke_response"
        return 1
    fi
    
    # Test Zendesk Lambda (this may fail if credentials aren't configured, which is OK)
    local zendesk_response
    zendesk_response=$(aws lambda invoke \
        --function-name "novabot-zendesk-create-ticket-$ENVIRONMENT" \
        --payload '{"body": "{\"subject\": \"Test\", \"description\": \"Test ticket\"}", "headers": {}}' \
        /tmp/zendesk_response.json 2>&1 || echo "failed")
    
    if [[ "$zendesk_response" != "failed" ]]; then
        local status_code
        status_code=$(jq -r '.statusCode // 500' /tmp/zendesk_response.json 2>/dev/null || echo "500")
        
        if [[ "$status_code" == "200" || "$status_code" == "400" || "$status_code" == "401" ]]; then
            log_info "Zendesk Lambda function deployed and responding"
        else
            log_warning "Zendesk Lambda may have configuration issues (status: $status_code)"
        fi
    else
        log_warning "Zendesk Lambda test failed - may need credential configuration"
    fi
    
    # Cleanup
    rm -f /tmp/invoke_response.json /tmp/zendesk_response.json
    
    return 0
}

# 7. Verify web widget files
verify_web_widget() {
    log_info "Checking web widget files..."
    
    local widget_dir="$PROJECT_ROOT/web/widget"
    
    if [[ ! -d "$widget_dir" ]]; then
        log_error "Web widget directory not found"
        return 1
    fi
    
    local required_files=("widget.js" "widget.css")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$widget_dir/$file" ]]; then
            log_error "Widget file not found: $file"
            return 1
        fi
        
        # Check file is not empty
        if [[ ! -s "$widget_dir/$file" ]]; then
            log_error "Widget file is empty: $file"
            return 1
        fi
    done
    
    # Basic syntax check for JavaScript
    if command -v node &>/dev/null; then
        if ! node -c "$widget_dir/widget.js" &>/dev/null; then
            log_error "JavaScript syntax error in widget.js"
            return 1
        fi
        log_info "Web widget JavaScript syntax is valid"
    fi
    
    return 0
}

# 8. Verify CI/CD pipeline configuration
verify_cicd_pipeline() {
    log_info "Checking CI/CD pipeline configuration..."
    
    local github_dir="$PROJECT_ROOT/.github/workflows"
    
    if [[ ! -d "$github_dir" ]]; then
        log_warning "GitHub workflows directory not found"
        return 0  # Not critical
    fi
    
    local workflow_files=("terraform.yml" "lambda-ci.yml")
    local found_workflows=0
    
    for workflow in "${workflow_files[@]}"; do
        if [[ -f "$github_dir/$workflow" ]]; then
            ((found_workflows++))
            log_info "Found workflow: $workflow"
        fi
    done
    
    if [[ $found_workflows -gt 0 ]]; then
        log_info "CI/CD pipeline configured with $found_workflows workflow(s)"
        return 0
    else
        log_warning "No CI/CD workflows found"
        return 0  # Not critical
    fi
}

# 9. Verify documentation completeness
verify_documentation() {
    log_info "Checking documentation completeness..."
    
    local doc_files=(
        "README.md"
        "docs/setup/complete-setup.md"
        "docs/troubleshooting/common-issues.md"
        "docs/api/reference.md"
    )
    
    local missing_docs=()
    
    for doc_file in "${doc_files[@]}"; do
        local full_path="$PROJECT_ROOT/$doc_file"
        if [[ ! -f "$full_path" ]]; then
            missing_docs+=("$doc_file")
        elif [[ ! -s "$full_path" ]]; then
            missing_docs+=("$doc_file (empty)")
        fi
    done
    
    if [[ ${#missing_docs[@]} -gt 0 ]]; then
        log_warning "Missing or empty documentation files:"
        for doc in "${missing_docs[@]}"; do
            echo "  - $doc"
        done
        return 0  # Documentation is not critical for functionality
    else
        log_info "All key documentation files present"
        return 0
    fi
}

# 10. End-to-end conversation test
verify_end_to_end_flow() {
    log_info "Running end-to-end conversation test..."
    
    # Test a complete conversation flow through the API
    local conversation_tests=(
        "Hello, I need help"
        "How do I reset my password?"
        "Can you create a support ticket for me?"
    )
    
    local session_id="e2e-test-$(date +%s)"
    
    for i in "${!conversation_tests[@]}"; do
        local message="${conversation_tests[$i]}"
        log_info "Testing message $((i+1)): $message"
        
        local response
        response=$(curl -s -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -H "Origin: https://example.com" \
            -d "{\"message\": \"$message\", \"sessionId\": \"$session_id\"}" \
            -o "/tmp/e2e_response_$i.json" \
            "$SYSTEM_API_URL/chat")
        
        if [[ "$response" == "200" ]]; then
            # Check response contains valid content
            local response_text
            response_text=$(jq -r '.response // ""' "/tmp/e2e_response_$i.json" 2>/dev/null || echo "")
            
            if [[ -n "$response_text" && "$response_text" != "null" ]]; then
                log_info "✓ Message $((i+1)) received valid response"
            else
                log_error "✗ Message $((i+1)) received empty or invalid response"
                return 1
            fi
        else
            log_error "✗ Message $((i+1)) failed with HTTP status: $response"
            return 1
        fi
    done
    
    # Cleanup
    rm -f /tmp/e2e_response_*.json
    
    log_success "End-to-end conversation flow completed successfully"
    return 0
}

# Generate integration verification report
generate_verification_report() {
    log_header "NovaBot System Integration Verification Report"
    
    echo "Component Verification Results:"
    echo "==============================="
    
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    
    for result in "${VERIFICATION_RESULTS[@]}"; do
        IFS='|' read -r status component duration <<< "$result"
        ((total_checks++))
        
        if [[ "$status" == "PASS" ]]; then
            echo -e "${GREEN}✓${NC} $component ($duration)"
            ((passed_checks++))
        else
            echo -e "${RED}✗${NC} $component ($duration)"
            ((failed_checks++))
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "========"
    echo "Total verifications: $total_checks"
    echo "Passed: $passed_checks"
    echo "Failed: $failed_checks"
    
    if [[ $total_checks -gt 0 ]]; then
        local success_rate
        success_rate=$(echo "scale=1; $passed_checks * 100 / $total_checks" | bc -l 2>/dev/null || echo "N/A")
        echo "Success rate: ${success_rate}%"
    fi
    
    if [[ ${#CRITICAL_FAILURES[@]} -gt 0 ]]; then
        echo ""
        log_error "Critical Failures:"
        for failure in "${CRITICAL_FAILURES[@]}"; do
            echo "  - $failure"
        done
    fi
    
    echo ""
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log_success "🎉 SYSTEM INTEGRATION VERIFICATION PASSED!"
        log_success "NovaBot is fully deployed and operational!"
        echo ""
        log_info "System is ready for:"
        echo "  ✓ Production deployment"
        echo "  ✓ User acceptance testing"
        echo "  ✓ Live traffic"
        echo ""
        log_info "Next steps:"
        echo "  1. Configure production environment variables"
        echo "  2. Set up monitoring and alerting"
        echo "  3. Train content team on knowledge base management"
        echo "  4. Deploy web widget to production websites"
    else
        log_error "❌ SYSTEM INTEGRATION VERIFICATION FAILED!"
        log_error "System is not ready for production deployment."
        echo ""
        log_info "Please address the following before proceeding:"
        echo "  1. Review and fix all failed verifications"
        echo "  2. Ensure all AWS services are properly configured"
        echo "  3. Verify Terraform deployment completed successfully"
        echo "  4. Check AWS credentials and permissions"
        echo ""
        log_info "For troubleshooting help, see: docs/troubleshooting/common-issues.md"
    fi
}

# Main execution
main() {
    log_header "NovaBot System Integration Verification"
    
    log_info "Project: NovaBot AWS Bedrock Support Chatbot"
    log_info "Environment: $ENVIRONMENT"
    log_info "Session: $INTEGRATION_TEST_SESSION"
    echo ""
    
    # Check prerequisites
    local missing_tools=()
    for tool in aws terraform curl jq bc; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools before running verification"
        exit 1
    fi
    
    # Run all verification steps
    verify_component "Terraform Deployment Status" "verify_terraform_deployment" true
    verify_component "AWS Services Access" "verify_aws_services" true
    verify_component "Bedrock Agent Functionality" "verify_bedrock_agent" true
    verify_component "Knowledge Base Integration" "verify_knowledge_base_integration" false
    verify_component "API Gateway Endpoints" "verify_api_endpoints" true
    verify_component "Lambda Function Integrations" "verify_lambda_integrations" true
    verify_component "Web Widget Files" "verify_web_widget" false
    verify_component "CI/CD Pipeline Configuration" "verify_cicd_pipeline" false
    verify_component "Documentation Completeness" "verify_documentation" false
    verify_component "End-to-End Conversation Flow" "verify_end_to_end_flow" true
    
    # Generate final report
    generate_verification_report
    
    # Exit with appropriate code
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV        Environment to verify (dev|prod, default: dev)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT         Environment to verify (dev|prod)"
    echo "  AWS_REGION          AWS region (default: us-east-1)"
    echo ""
    echo "This script verifies that the complete NovaBot system is properly"
    echo "deployed and all components are working together correctly."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi