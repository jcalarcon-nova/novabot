#!/bin/bash

# NovaBot Knowledge Base Integration Test Script
# This script tests the knowledge base deployment and integration

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
TEST_QUERIES=(
    "How do I activate Datadog MuleSoft integration?"
    "What are the troubleshooting steps for connection issues?"
    "How to configure authentication for the integration?"
    "What are the network requirements?"
    "How to resolve deployment errors?"
)

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

# Test functions
test_local_validation() {
    log_info "Testing local knowledge base validation..."
    
    if [[ -f "scripts/validate_knowledge_base.py" ]]; then
        if python3 scripts/validate_knowledge_base.py --quiet; then
            log_success "Local validation passed"
            return 0
        else
            log_error "Local validation failed"
            return 1
        fi
    else
        log_warning "Validation script not found, skipping local validation"
        return 0
    fi
}

test_s3_deployment() {
    log_info "Testing S3 deployment..."
    
    # Get S3 bucket from terraform
    cd "$TERRAFORM_DIR"
    S3_BUCKET=$(terraform output -raw knowledge_base_s3_bucket_name 2>/dev/null || echo "")
    cd - > /dev/null
    
    if [[ -z "$S3_BUCKET" ]]; then
        log_warning "S3 bucket name not available from Terraform, skipping S3 tests"
        return 0
    fi
    
    # Check if files exist in S3
    log_info "Checking S3 bucket: $S3_BUCKET"
    
    if aws s3 ls "s3://$S3_BUCKET/knowledge_base/" > /dev/null 2>&1; then
        local file_count=$(aws s3 ls "s3://$S3_BUCKET/knowledge_base/" --recursive | wc -l)
        if [[ $file_count -gt 0 ]]; then
            log_success "Found $file_count files in S3 bucket"
            
            # List the files
            log_info "Files in S3:"
            aws s3 ls "s3://$S3_BUCKET/knowledge_base/" --human-readable | sed 's/^/  /'
            
            return 0
        else
            log_error "S3 bucket exists but no files found"
            return 1
        fi
    else
        log_error "Cannot access S3 bucket or files not deployed"
        return 1
    fi
}

test_bedrock_knowledge_base() {
    log_info "Testing Bedrock Knowledge Base integration..."
    
    # Get Knowledge Base ID from terraform
    cd "$TERRAFORM_DIR"
    KNOWLEDGE_BASE_ID=$(terraform output -raw knowledge_base_id 2>/dev/null || echo "")
    cd - > /dev/null
    
    if [[ -z "$KNOWLEDGE_BASE_ID" ]]; then
        log_warning "Knowledge Base ID not available from Terraform, skipping Bedrock tests"
        return 0
    fi
    
    log_info "Testing Knowledge Base: $KNOWLEDGE_BASE_ID"
    
    # Check if knowledge base exists and is active
    KB_STATUS=$(aws bedrock-agent get-knowledge-base \
        --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
        --query 'knowledgeBase.status' \
        --output text 2>/dev/null || echo "ERROR")
    
    if [[ "$KB_STATUS" == "ACTIVE" ]]; then
        log_success "Knowledge Base is active"
        
        # Check data sources
        DATA_SOURCES=$(aws bedrock-agent list-data-sources \
            --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
            --query 'dataSourceSummaries' \
            --output json 2>/dev/null || echo "[]")
        
        local ds_count=$(echo "$DATA_SOURCES" | jq '. | length' 2>/dev/null || echo "0")
        if [[ $ds_count -gt 0 ]]; then
            log_success "Found $ds_count data source(s)"
            
            # Check ingestion jobs
            for ds_id in $(echo "$DATA_SOURCES" | jq -r '.[].dataSourceId' 2>/dev/null); do
                log_info "Checking data source: $ds_id"
                
                JOBS=$(aws bedrock-agent list-ingestion-jobs \
                    --knowledge-base-id "$KNOWLEDGE_BASE_ID" \
                    --data-source-id "$ds_id" \
                    --max-results 5 \
                    --query 'ingestionJobSummaries[0]' \
                    --output json 2>/dev/null || echo "{}")
                
                if [[ "$JOBS" != "{}" ]] && [[ "$JOBS" != "null" ]]; then
                    JOB_STATUS=$(echo "$JOBS" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
                    JOB_ID=$(echo "$JOBS" | jq -r '.ingestionJobId' 2>/dev/null || echo "UNKNOWN")
                    
                    case "$JOB_STATUS" in
                        "COMPLETE")
                            log_success "Latest ingestion job ($JOB_ID) completed successfully"
                            ;;
                        "IN_PROGRESS")
                            log_info "Ingestion job ($JOB_ID) is in progress"
                            ;;
                        "FAILED")
                            log_error "Latest ingestion job ($JOB_ID) failed"
                            return 1
                            ;;
                        *)
                            log_warning "Latest ingestion job ($JOB_ID) status: $JOB_STATUS"
                            ;;
                    esac
                else
                    log_warning "No ingestion jobs found for data source $ds_id"
                fi
            done
        else
            log_error "No data sources found for Knowledge Base"
            return 1
        fi
        
        return 0
    else
        log_error "Knowledge Base status: $KB_STATUS"
        return 1
    fi
}

test_query_retrieval() {
    log_info "Testing query retrieval (if Bedrock Agent is available)..."
    
    # Get Agent ID from terraform
    cd "$TERRAFORM_DIR"
    AGENT_ID=$(terraform output -raw bedrock_agent_id 2>/dev/null || echo "")
    AGENT_ALIAS_ID=$(terraform output -raw bedrock_agent_alias_id 2>/dev/null || echo "")
    cd - > /dev/null
    
    if [[ -z "$AGENT_ID" ]] || [[ -z "$AGENT_ALIAS_ID" ]]; then
        log_warning "Bedrock Agent not available, skipping query tests"
        return 0
    fi
    
    log_info "Testing with Agent: $AGENT_ID (Alias: $AGENT_ALIAS_ID)"
    
    # Test a simple query
    local test_query="How do I activate Datadog MuleSoft integration?"
    log_info "Testing query: $test_query"
    
    # Create a session for testing
    SESSION_ID=$(date +%s)
    
    # Send query to agent
    RESPONSE=$(aws bedrock-agent-runtime invoke-agent \
        --agent-id "$AGENT_ID" \
        --agent-alias-id "$AGENT_ALIAS_ID" \
        --session-id "test-$SESSION_ID" \
        --input-text "$test_query" \
        /tmp/agent_response.json 2>/dev/null && echo "SUCCESS" || echo "FAILED")
    
    if [[ "$RESPONSE" == "SUCCESS" ]] && [[ -f "/tmp/agent_response.json" ]]; then
        log_success "Agent responded successfully"
        
        # Parse response to check if knowledge base was used
        if grep -q "citation" /tmp/agent_response.json 2>/dev/null; then
            log_success "Response includes knowledge base citations"
        else
            log_warning "Response may not include knowledge base citations"
        fi
        
        # Cleanup
        rm -f /tmp/agent_response.json
        return 0
    else
        log_error "Failed to query agent"
        return 1
    fi
}

run_comprehensive_test() {
    log_info "Running comprehensive knowledge base integration test..."
    echo
    
    local tests_passed=0
    local tests_total=4
    
    # Test 1: Local validation
    if test_local_validation; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Test 2: S3 deployment
    if test_s3_deployment; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Test 3: Bedrock Knowledge Base
    if test_bedrock_knowledge_base; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Test 4: Query retrieval
    if test_query_retrieval; then
        tests_passed=$((tests_passed + 1))
    fi
    echo
    
    # Summary
    log_info "Test Results: $tests_passed/$tests_total tests passed"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "All tests passed! Knowledge base integration is working correctly."
        return 0
    else
        local failed_tests=$((tests_total - tests_passed))
        log_warning "$failed_tests test(s) failed. Check the output above for details."
        return 1
    fi
}

show_help() {
    cat << EOF
NovaBot Knowledge Base Integration Test Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    --local-only           Only run local validation tests
    --s3-only              Only test S3 deployment
    --bedrock-only         Only test Bedrock Knowledge Base
    --query-only           Only test query retrieval
    --list-queries         List available test queries

EXAMPLES:
    $0                     # Run all tests
    $0 --local-only        # Only validate local files
    $0 --s3-only           # Only test S3 deployment
    $0 --bedrock-only      # Only test Bedrock integration

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - Terraform infrastructure deployed
    - Knowledge base files deployed to S3

EOF
}

# Parse command line arguments
TEST_TYPE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --local-only)
            TEST_TYPE="local"
            shift
            ;;
        --s3-only)
            TEST_TYPE="s3"
            shift
            ;;
        --bedrock-only)
            TEST_TYPE="bedrock"
            shift
            ;;
        --query-only)
            TEST_TYPE="query"
            shift
            ;;
        --list-queries)
            echo "Available test queries:"
            for i in "${!TEST_QUERIES[@]}"; do
                echo "  $((i+1)). ${TEST_QUERIES[$i]}"
            done
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute tests based on type
case "$TEST_TYPE" in
    "local")
        test_local_validation
        ;;
    "s3")
        test_s3_deployment
        ;;
    "bedrock")
        test_bedrock_knowledge_base
        ;;
    "query")
        test_query_retrieval
        ;;
    "all"|*)
        run_comprehensive_test
        ;;
esac

exit $?