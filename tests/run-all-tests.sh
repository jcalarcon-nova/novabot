#!/bin/bash

# NovaBot Complete Test Suite Runner
# This script runs all validation tests for the NovaBot system

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
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="${PROJECT_ROOT}/tests"
ENVIRONMENT="${ENVIRONMENT:-dev}"
VERBOSE="${VERBOSE:-false}"
SKIP_INFRASTRUCTURE="${SKIP_INFRASTRUCTURE:-false}"
SKIP_LAMBDA="${SKIP_LAMBDA:-false}"
SKIP_API="${SKIP_API:-false}"

# Test results tracking
SUITE_RESULTS=()
OVERALL_SUCCESS=true

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

log_header() {
    echo ""
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN} $1${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo ""
}

# Run a test suite
run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    local description="$3"
    
    log_header "$suite_name"
    log_info "$description"
    
    local start_time
    start_time=$(date +%s)
    
    # Make script executable if it isn't already
    if [[ -f "$test_script" ]]; then
        chmod +x "$test_script"
    else
        log_error "Test script not found: $test_script"
        SUITE_RESULTS+=("FAIL|$suite_name|Script not found")
        OVERALL_SUCCESS=false
        return 1
    fi
    
    # Run the test script
    local exit_code=0
    if [[ "$VERBOSE" == "true" ]]; then
        "$test_script" || exit_code=$?
    else
        "$test_script" > /tmp/test_output_$$.log 2>&1 || exit_code=$?
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$suite_name completed successfully (${duration}s)"
        SUITE_RESULTS+=("PASS|$suite_name|${duration}s")
    else
        log_error "$suite_name failed (${duration}s)"
        SUITE_RESULTS+=("FAIL|$suite_name|${duration}s")
        OVERALL_SUCCESS=false
        
        # Show error output if not in verbose mode
        if [[ "$VERBOSE" != "true" && -f "/tmp/test_output_$$.log" ]]; then
            echo ""
            log_error "Error output from $suite_name:"
            echo "----------------------------------------"
            tail -20 "/tmp/test_output_$$.log"
            echo "----------------------------------------"
        fi
    fi
    
    # Cleanup temp log file
    rm -f "/tmp/test_output_$$.log"
    
    return $exit_code
}

# Check prerequisites
check_prerequisites() {
    log_header "Prerequisites Check"
    
    local missing_deps=()
    
    # Check required commands
    local required_commands=("terraform" "aws" "node" "npm" "curl" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        missing_deps+=("AWS credentials")
    fi
    
    # Check Node.js version
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node --version | sed 's/v//')
        local major_version
        major_version=$(echo "$node_version" | cut -d. -f1)
        
        if [[ $major_version -lt 18 ]]; then
            log_warning "Node.js version $node_version detected. Version 18+ recommended."
        fi
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        return 1
    else
        log_success "All prerequisites met"
        return 0
    fi
}

# Install test dependencies
install_test_dependencies() {
    log_info "Installing test dependencies..."
    
    # Check if npm packages need to be installed for tests
    if [[ -f "$TESTS_DIR/package.json" ]]; then
        cd "$TESTS_DIR"
        if ! npm install --silent; then
            log_warning "Failed to install test dependencies"
        else
            log_success "Test dependencies installed"
        fi
    fi
    
    # Install js-yaml if not available (for OpenAPI validation)
    if ! node -e "require('js-yaml')" 2>/dev/null; then
        log_info "Installing js-yaml for OpenAPI validation..."
        npm install -g js-yaml --silent || log_warning "Failed to install js-yaml"
    fi
}

# Generate final report
generate_final_report() {
    echo ""
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN}  NovaBot Complete Test Suite Report${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo ""
    
    echo "Test Suite Results:"
    echo "==================="
    
    local total_suites=0
    local passed_suites=0
    local failed_suites=0
    
    for result in "${SUITE_RESULTS[@]}"; do
        IFS='|' read -r status suite_name duration <<< "$result"
        ((total_suites++))
        
        if [[ "$status" == "PASS" ]]; then
            echo -e "${GREEN}✓${NC} $suite_name ($duration)"
            ((passed_suites++))
        else
            echo -e "${RED}✗${NC} $suite_name ($duration)"
            ((failed_suites++))
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "========"
    echo "Total test suites: $total_suites"
    echo "Passed: $passed_suites"
    echo "Failed: $failed_suites"
    
    if [[ $total_suites -gt 0 ]]; then
        local success_rate
        success_rate=$(echo "scale=1; $passed_suites * 100 / $total_suites" | bc -l 2>/dev/null || echo "N/A")
        echo "Success rate: ${success_rate}%"
    fi
    
    echo ""
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        log_success "🎉 All test suites passed!"
        log_success "NovaBot system is fully validated and ready for deployment!"
    else
        log_error "❌ Some test suites failed!"
        log_error "Please review and fix the issues before proceeding with deployment."
        echo ""
        log_info "Troubleshooting tips:"
        echo "- Check individual test outputs for specific error messages"
        echo "- Verify AWS credentials and permissions"
        echo "- Ensure all prerequisites are properly installed"
        echo "- Review the troubleshooting guide: docs/troubleshooting/common-issues.md"
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV                Environment (dev|prod, default: dev)"
    echo "  -v, --verbose               Enable verbose output"
    echo "  --skip-infrastructure       Skip infrastructure validation tests"
    echo "  --skip-lambda               Skip Lambda function tests"
    echo "  --skip-api                  Skip API endpoint tests"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT                 Environment (dev|prod)"
    echo "  VERBOSE                     Enable verbose output (true|false)"
    echo "  SKIP_INFRASTRUCTURE         Skip infrastructure tests (true|false)"
    echo "  SKIP_LAMBDA                 Skip Lambda tests (true|false)"
    echo "  SKIP_API                    Skip API tests (true|false)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run all tests"
    echo "  $0 -v                       # Run with verbose output"
    echo "  $0 --skip-api               # Skip API endpoint tests"
    echo "  ENVIRONMENT=prod $0         # Run tests for prod environment"
}

# Main execution function
main() {
    echo -e "${BOLD}${CYAN}NovaBot Complete Test Suite${NC}"
    echo -e "${BOLD}${CYAN}===========================${NC}"
    echo ""
    log_info "Project root: $PROJECT_ROOT"
    log_info "Environment: $ENVIRONMENT"
    log_info "Verbose mode: $VERBOSE"
    echo ""
    
    # Check prerequisites first
    if ! check_prerequisites; then
        log_error "Prerequisites check failed. Please install missing dependencies."
        exit 1
    fi
    
    # Install test dependencies
    install_test_dependencies
    
    # Run test suites based on configuration
    if [[ "$SKIP_INFRASTRUCTURE" != "true" ]]; then
        run_test_suite \
            "Infrastructure Validation" \
            "$TESTS_DIR/validate-infrastructure.sh" \
            "Validating Terraform modules, AWS resources, and configuration files"
    else
        log_warning "Skipping infrastructure validation tests"
    fi
    
    if [[ "$SKIP_LAMBDA" != "true" ]]; then
        run_test_suite \
            "Lambda Functions" \
            "node $TESTS_DIR/test-lambda-functions.js" \
            "Testing Lambda function compilation, dependencies, and structure"
    else
        log_warning "Skipping Lambda function tests"
    fi
    
    if [[ "$SKIP_API" != "true" ]]; then
        run_test_suite \
            "API Endpoints" \
            "$TESTS_DIR/test-api-endpoints.sh" \
            "Testing API Gateway endpoints, CORS, error handling, and performance"
    else
        log_warning "Skipping API endpoint tests"
    fi
    
    # Generate final report
    generate_final_report
    
    # Exit with appropriate code
    if [[ "$OVERALL_SUCCESS" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        --skip-infrastructure)
            SKIP_INFRASTRUCTURE="true"
            shift
            ;;
        --skip-lambda)
            SKIP_LAMBDA="true"
            shift
            ;;
        --skip-api)
            SKIP_API="true"
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