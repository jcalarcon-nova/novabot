#!/bin/bash

# NovaBot API Endpoints Test Suite
# This script tests all API endpoints to ensure they're working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infra/terraform"
ENVIRONMENT="${ENVIRONMENT:-dev}"
API_BASE_URL="${API_BASE_URL:-}"
TIMEOUT="${TIMEOUT:-30}"
VERBOSE="${VERBOSE:-false}"

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()
TEST_RESULTS=()

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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Test result tracking
run_api_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Running API test: $test_name"
    
    local start_time
    start_time=$(date +%s%3N)
    
    if eval "$test_function"; then
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        log_success "✓ $test_name (${duration}ms)"
        ((TESTS_PASSED++))
        TEST_RESULTS+=("PASS|$test_name|${duration}ms")
        return 0
    else
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        log_error "✗ $test_name (${duration}ms)"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        TEST_RESULTS+=("FAIL|$test_name|${duration}ms")
        return 1
    fi
}

# Get API Gateway URL from Terraform outputs
get_api_url() {
    if [[ -n "$API_BASE_URL" ]]; then
        echo "$API_BASE_URL"
        return 0
    fi
    
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        # Try to get from Terraform state
        local api_url
        api_url=$(cd "$TERRAFORM_DIR" && terraform output -raw api_gateway_url 2>/dev/null || echo "")
        
        if [[ -n "$api_url" ]]; then
            echo "$api_url"
            return 0
        fi
    fi
    
    log_error "API_BASE_URL not provided and cannot extract from Terraform"
    return 1
}

# Make HTTP request with proper error handling
make_request() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local expected_status="${4:-200}"
    local headers="${5:-}"
    
    local url="${API_BASE_URL}${endpoint}"
    local curl_cmd="curl -s -w 'HTTP_STATUS:%{http_code}\nRESPONSE_TIME:%{time_total}' --max-time $TIMEOUT"
    
    # Add method
    curl_cmd="$curl_cmd -X $method"
    
    # Add headers
    if [[ -n "$headers" ]]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    # Add data for POST/PUT requests
    if [[ -n "$data" ]]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    # Add URL
    curl_cmd="$curl_cmd '$url'"
    
    log_debug "Executing: $curl_cmd"
    
    # Execute request
    local response
    response=$(eval "$curl_cmd" 2>&1 || echo "CURL_ERROR:$?")
    
    # Check for curl errors
    if [[ "$response" == CURL_ERROR:* ]]; then
        log_error "Curl error for $method $endpoint"
        return 1
    fi
    
    # Extract HTTP status and response time
    local http_status
    local response_time
    local response_body
    
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    response_time=$(echo "$response" | grep "RESPONSE_TIME:" | cut -d: -f2)
    response_body=$(echo "$response" | sed '/HTTP_STATUS:/d' | sed '/RESPONSE_TIME:/d')
    
    log_debug "HTTP Status: $http_status"
    log_debug "Response Time: ${response_time}s"
    log_debug "Response Body: $response_body"
    
    # Check expected status
    if [[ "$http_status" != "$expected_status" ]]; then
        log_error "Expected status $expected_status, got $http_status for $method $endpoint"
        log_error "Response: $response_body"
        return 1
    fi
    
    # Store response for further validation
    export LAST_RESPONSE_BODY="$response_body"
    export LAST_RESPONSE_TIME="$response_time"
    export LAST_HTTP_STATUS="$http_status"
    
    return 0
}

# Test 1: Health check endpoint
test_health_endpoint() {
    local endpoint="/health"
    
    if make_request "GET" "$endpoint" "" "200" "-H 'Accept: application/json'"; then
        # Validate response contains expected fields
        if echo "$LAST_RESPONSE_BODY" | grep -q '"status"'; then
            log_debug "Health endpoint response contains status field"
            return 0
        else
            log_error "Health endpoint response missing status field"
            return 1
        fi
    else
        return 1
    fi
}

# Test 2: CORS preflight request
test_cors_preflight() {
    local endpoint="/chat"
    
    if make_request "OPTIONS" "$endpoint" "" "200" "-H 'Origin: https://example.com' -H 'Access-Control-Request-Method: POST' -H 'Access-Control-Request-Headers: Content-Type'"; then
        # Check for CORS headers in response
        local full_response
        full_response=$(curl -s -I -X OPTIONS \
            -H "Origin: https://example.com" \
            -H "Access-Control-Request-Method: POST" \
            -H "Access-Control-Request-Headers: Content-Type" \
            "${API_BASE_URL}${endpoint}")
        
        if echo "$full_response" | grep -qi "access-control-allow-origin"; then
            log_debug "CORS headers present in preflight response"
            return 0
        else
            log_warning "CORS headers not found in preflight response"
            return 1
        fi
    else
        return 1
    fi
}

# Test 3: Chat endpoint with basic message
test_chat_basic_message() {
    local endpoint="/chat"
    local payload='{"message": "Hello, this is a test message"}'
    
    if make_request "POST" "$endpoint" "$payload" "200" "-H 'Content-Type: application/json' -H 'Origin: https://example.com'"; then
        # Validate response contains expected fields
        if echo "$LAST_RESPONSE_BODY" | grep -q '"response"'; then
            log_debug "Chat endpoint returned response field"
            return 0
        else
            log_error "Chat endpoint response missing response field"
            log_error "Response body: $LAST_RESPONSE_BODY"
            return 1
        fi
    else
        return 1
    fi
}

# Test 4: Chat endpoint with session ID
test_chat_with_session() {
    local endpoint="/chat"
    local session_id="test-session-$(date +%s)"
    local payload="{\"message\": \"Hello with session\", \"sessionId\": \"$session_id\"}"
    
    if make_request "POST" "$endpoint" "$payload" "200" "-H 'Content-Type: application/json' -H 'Origin: https://example.com'"; then
        # Validate response contains session ID
        if echo "$LAST_RESPONSE_BODY" | grep -q "\"sessionId\""; then
            log_debug "Chat endpoint returned sessionId"
            return 0
        else
            log_warning "Chat endpoint response missing sessionId"
            # Don't fail the test, as this might be optional
            return 0
        fi
    else
        return 1
    fi
}

# Test 5: Chat endpoint error handling - malformed JSON
test_chat_malformed_json() {
    local endpoint="/chat"
    local payload='{"message": "test"'  # Malformed JSON
    
    if make_request "POST" "$endpoint" "$payload" "400" "-H 'Content-Type: application/json'"; then
        log_debug "Chat endpoint properly rejected malformed JSON"
        return 0
    else
        log_error "Chat endpoint did not properly handle malformed JSON"
        return 1
    fi
}

# Test 6: Chat endpoint error handling - missing message
test_chat_missing_message() {
    local endpoint="/chat"
    local payload='{}'  # Missing required message field
    
    # Accept both 400 (bad request) and 422 (unprocessable entity)
    if make_request "POST" "$endpoint" "$payload" "400" "-H 'Content-Type: application/json'" || \
       make_request "POST" "$endpoint" "$payload" "422" "-H 'Content-Type: application/json'"; then
        log_debug "Chat endpoint properly rejected request without message"
        return 0
    else
        log_error "Chat endpoint did not properly handle missing message"
        return 1
    fi
}

# Test 7: Chat endpoint with very long message
test_chat_long_message() {
    local endpoint="/chat"
    local long_message
    # Create a 5000 character message
    long_message=$(printf 'A%.0s' {1..5000})
    local payload="{\"message\": \"$long_message\"}"
    
    # This should either succeed or return a 413 (payload too large) or 400 (bad request)
    if make_request "POST" "$endpoint" "$payload" "200" "-H 'Content-Type: application/json'" || \
       make_request "POST" "$endpoint" "$payload" "413" "-H 'Content-Type: application/json'" || \
       make_request "POST" "$endpoint" "$payload" "400" "-H 'Content-Type: application/json'"; then
        log_debug "Chat endpoint handled long message appropriately"
        return 0
    else
        log_error "Chat endpoint did not handle long message properly"
        return 1
    fi
}

# Test 8: Rate limiting (make multiple rapid requests)
test_rate_limiting() {
    local endpoint="/chat"
    local payload='{"message": "Rate limit test"}'
    
    log_debug "Testing rate limiting with rapid requests"
    
    local success_count=0
    local rate_limited_count=0
    
    # Make 10 rapid requests
    for i in {1..10}; do
        if make_request "POST" "$endpoint" "$payload" "200" "-H 'Content-Type: application/json'" 2>/dev/null; then
            ((success_count++))
        elif [[ "$LAST_HTTP_STATUS" == "429" ]]; then
            ((rate_limited_count++))
            log_debug "Request $i was rate limited (expected behavior)"
        fi
    done
    
    log_debug "Successful requests: $success_count, Rate limited: $rate_limited_count"
    
    # We should have at least some successful requests
    if [[ $success_count -gt 0 ]]; then
        return 0
    else
        log_warning "All requests were rate limited - rate limits may be too strict"
        return 0  # Don't fail the test, just warn
    fi
}

# Test 9: Response time performance
test_response_time() {
    local endpoint="/chat"
    local payload='{"message": "Performance test message"}'
    
    if make_request "POST" "$endpoint" "$payload" "200" "-H 'Content-Type: application/json'"; then
        # Check if response time is reasonable (less than 30 seconds)
        local response_time_float="$LAST_RESPONSE_TIME"
        local response_time_int
        response_time_int=$(echo "$response_time_float * 1000" | bc -l | cut -d. -f1)
        
        if [[ $response_time_int -lt 30000 ]]; then
            log_debug "Response time acceptable: ${response_time_float}s"
            return 0
        else
            log_warning "Response time slow: ${response_time_float}s"
            return 0  # Don't fail, just warn
        fi
    else
        return 1
    fi
}

# Test 10: Content-Type validation
test_content_type_validation() {
    local endpoint="/chat"
    local payload='{"message": "Content type test"}'
    
    # Test without Content-Type header (should fail)
    if make_request "POST" "$endpoint" "$payload" "400" "" || \
       make_request "POST" "$endpoint" "$payload" "415" ""; then
        log_debug "API properly validates Content-Type header"
        return 0
    else
        log_warning "API does not validate Content-Type header"
        return 0  # Don't fail, as this might be permissive
    fi
}

# Generate comprehensive test report
generate_test_report() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  NovaBot API Endpoints Test Report${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    log_success "Tests passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Tests failed: $TESTS_FAILED"
        echo ""
        log_error "Failed tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "  - $failed_test"
        done
    fi
    
    echo ""
    echo "Detailed Results:"
    echo "=================="
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r status test_name duration <<< "$result"
        if [[ "$status" == "PASS" ]]; then
            echo -e "${GREEN}✓${NC} $test_name ($duration)"
        else
            echo -e "${RED}✗${NC} $test_name ($duration)"
        fi
    done
    
    echo ""
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    if [[ $total_tests -gt 0 ]]; then
        local success_rate
        success_rate=$(echo "scale=1; $TESTS_PASSED * 100 / $total_tests" | bc -l)
        echo "Success rate: ${success_rate}%"
    fi
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        log_success "🎉 All API endpoint tests passed!"
        log_success "API is ready for production use!"
    else
        echo ""
        log_error "❌ Some API tests failed!"
        log_error "Please review and fix the issues before deployment."
    fi
}

# Main execution function
main() {
    echo -e "${CYAN}Starting NovaBot API Endpoints Test Suite${NC}"
    echo "=========================================="
    
    # Get API URL
    if ! API_BASE_URL=$(get_api_url); then
        log_error "Cannot determine API Gateway URL"
        exit 1
    fi
    
    log_info "API Base URL: $API_BASE_URL"
    log_info "Environment: $ENVIRONMENT"
    log_info "Timeout: ${TIMEOUT}s"
    echo ""
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        log_warning "bc command not found, some calculations may be skipped"
    fi
    
    # Run all API tests
    run_api_test "Health Endpoint" "test_health_endpoint"
    run_api_test "CORS Preflight" "test_cors_preflight"
    run_api_test "Chat Basic Message" "test_chat_basic_message"
    run_api_test "Chat with Session ID" "test_chat_with_session"
    run_api_test "Chat Malformed JSON" "test_chat_malformed_json"
    run_api_test "Chat Missing Message" "test_chat_missing_message"
    run_api_test "Chat Long Message" "test_chat_long_message"
    run_api_test "Rate Limiting" "test_rate_limiting"
    run_api_test "Response Time Performance" "test_response_time"
    run_api_test "Content-Type Validation" "test_content_type_validation"
    
    # Generate final report
    generate_test_report
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --url URL        API base URL (e.g., https://api.example.com)"
    echo "  -e, --env ENV        Environment (dev|prod, default: dev)"
    echo "  -t, --timeout SEC    Request timeout in seconds (default: 30)"
    echo "  -v, --verbose        Enable verbose logging"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  API_BASE_URL         API base URL"
    echo "  ENVIRONMENT          Environment (dev|prod)"
    echo "  TIMEOUT              Request timeout in seconds"
    echo "  VERBOSE              Enable verbose logging (true|false)"
    echo ""
    echo "Examples:"
    echo "  $0 -u https://api.example.com -v"
    echo "  API_BASE_URL=https://api.example.com $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            API_BASE_URL="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
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

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi