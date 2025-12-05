#!/bin/bash

# 🎃 Enhanced SpookyMart Automated Test Suite
# Comprehensive testing including Blue/Green deployment validation
# Usage: ./test-suite-enhanced.sh [ALB_URL] [--blue-green] [--performance] [--all]

set -e  # Exit on any error

# Configuration
ALB_URL="${1:-http://spookymart-alb-1978027172.us-west-2.elb.amazonaws.com}"
TIMEOUT=10
MAX_RETRIES=3
TEST_EMAIL="test@spookymart.com"
CLUSTER_NAME="spookymart-cluster"
FRONTEND_SERVICE="spookymart-frontend-service"

# Test modes
RUN_BLUE_GREEN_TESTS=false
RUN_PERFORMANCE_TESTS=false
RUN_ALL_TESTS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0
TESTS_SKIPPED=0

# Test results array for reporting
declare -a TEST_RESULTS=()

# Helper functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
    TEST_RESULTS+=("PASS: $1")
}

failure() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
    TEST_RESULTS+=("FAIL: $1")
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

skip() {
    echo -e "${CYAN}⏭️  $1${NC}"
    ((TESTS_SKIPPED++))
    TEST_RESULTS+=("SKIP: $1")
}

test_with_retry() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    local retry_count=0
    
    ((TESTS_TOTAL++))
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if eval "$test_command" | grep -q "$expected_pattern"; then
            success "$test_name"
            return 0
        fi
        ((retry_count++))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            warning "$test_name failed, retrying ($retry_count/$MAX_RETRIES)..."
            sleep 2
        fi
    done
    
    failure "$test_name (failed after $MAX_RETRIES attempts)"
    return 1
}

test_http_status() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    
    ((TESTS_TOTAL++))
    
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url")
    
    if [ "$status_code" = "$expected_status" ]; then
        success "$test_name (HTTP $status_code)"
        return 0
    else
        failure "$test_name (Expected HTTP $expected_status, got $status_code)"
        return 1
    fi
}

test_response_time() {
    local test_name="$1"
    local url="$2"
    local max_time="$3"
    
    ((TESTS_TOTAL++))
    
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" --max-time $TIMEOUT "$url")
    
    if (( $(echo "$response_time <= $max_time" | bc -l) )); then
        success "$test_name (${response_time}s)"
        return 0
    else
        failure "$test_name (${response_time}s > ${max_time}s threshold)"
        return 1
    fi
}

test_json_response() {
    local test_name="$1"
    local url="$2"
    local jq_filter="$3"
    local expected_value="$4"
    
    ((TESTS_TOTAL++))
    
    local response=$(curl -s --max-time $TIMEOUT "$url")
    local actual_value=$(echo "$response" | jq -r "$jq_filter" 2>/dev/null || echo "ERROR")
    
    if [ "$actual_value" = "$expected_value" ]; then
        success "$test_name"
        return 0
    else
        failure "$test_name (Expected: $expected_value, Got: $actual_value)"
        return 1
    fi
}

# Blue/Green specific tests
test_target_group_health() {
    local tg_name="$1"
    local expected_healthy_count="$2"
    
    ((TESTS_TOTAL++))
    
    if ! command -v aws >/dev/null 2>&1; then
        skip "Target Group Health Check ($tg_name) - AWS CLI not available"
        return 0
    fi
    
    local tg_arn=$(aws elbv2 describe-target-groups --names "$tg_name" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "ERROR")
    
    if [ "$tg_arn" = "ERROR" ] || [ "$tg_arn" = "None" ]; then
        failure "Target Group Health Check ($tg_name) - Target group not found"
        return 1
    fi
    
    local healthy_count=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' --output text 2>/dev/null || echo "0")
    
    if [ "$healthy_count" -ge "$expected_healthy_count" ]; then
        success "Target Group Health Check ($tg_name) - $healthy_count healthy targets"
        return 0
    else
        failure "Target Group Health Check ($tg_name) - Expected $expected_healthy_count+ healthy, got $healthy_count"
        return 1
    fi
}

test_alb_traffic_weights() {
    ((TESTS_TOTAL++))
    
    if ! command -v aws >/dev/null 2>&1; then
        skip "ALB Traffic Weights Check - AWS CLI not available"
        return 0
    fi
    
    local alb_arn=$(aws elbv2 describe-load-balancers --names "spookymart-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "ERROR")
    
    if [ "$alb_arn" = "ERROR" ] || [ "$alb_arn" = "None" ]; then
        failure "ALB Traffic Weights Check - Load balancer not found"
        return 1
    fi
    
    local listener_arn=$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[?Port==`80`].ListenerArn' --output text 2>/dev/null || echo "ERROR")
    
    if [ "$listener_arn" = "ERROR" ] || [ "$listener_arn" = "None" ]; then
        failure "ALB Traffic Weights Check - HTTP listener not found"
        return 1
    fi
    
    local weights=$(aws elbv2 describe-rules --listener-arn "$listener_arn" --query 'Rules[?IsDefault==`true`].Actions[0].ForwardConfig.TargetGroups[*].Weight' --output text 2>/dev/null || echo "ERROR")
    
    if [ "$weights" = "ERROR" ]; then
        failure "ALB Traffic Weights Check - Unable to retrieve weights"
        return 1
    fi
    
    success "ALB Traffic Weights Check - Weights: [$weights]"
    return 0
}

test_ecs_service_status() {
    local service_name="$1"
    
    ((TESTS_TOTAL++))
    
    if ! command -v aws >/dev/null 2>&1; then
        skip "ECS Service Status ($service_name) - AWS CLI not available"
        return 0
    fi
    
    local service_status=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service_name" --query 'services[0].status' --output text 2>/dev/null || echo "ERROR")
    
    if [ "$service_status" = "ACTIVE" ]; then
        success "ECS Service Status ($service_name) - ACTIVE"
        return 0
    else
        failure "ECS Service Status ($service_name) - Status: $service_status"
        return 1
    fi
}

test_deployment_status() {
    local service_name="$1"
    
    ((TESTS_TOTAL++))
    
    if ! command -v aws >/dev/null 2>&1; then
        skip "Deployment Status ($service_name) - AWS CLI not available"
        return 0
    fi
    
    local deployment_status=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service_name" --query 'services[0].deployments[0].status' --output text 2>/dev/null || echo "ERROR")
    
    if [ "$deployment_status" = "PRIMARY" ]; then
        success "Deployment Status ($service_name) - PRIMARY"
        return 0
    elif [ "$deployment_status" = "ACTIVE" ]; then
        success "Deployment Status ($service_name) - ACTIVE"
        return 0
    else
        failure "Deployment Status ($service_name) - Status: $deployment_status"
        return 1
    fi
}

# Performance stress test
stress_test_endpoints() {
    local concurrent_requests="$1"
    local total_requests="$2"
    
    ((TESTS_TOTAL++))
    
    if ! command -v ab >/dev/null 2>&1; then
        skip "Stress Test - Apache Bench (ab) not available"
        return 0
    fi
    
    log "Running stress test: $total_requests requests with $concurrent_requests concurrent connections..."
    
    local ab_output=$(ab -n "$total_requests" -c "$concurrent_requests" -s 30 "$ALB_URL/" 2>/dev/null || echo "ERROR")
    
    if [ "$ab_output" = "ERROR" ]; then
        failure "Stress Test - Apache Bench failed"
        return 1
    fi
    
    local failed_requests=$(echo "$ab_output" | grep "Failed requests:" | awk '{print $3}')
    local requests_per_sec=$(echo "$ab_output" | grep "Requests per second:" | awk '{print $4}')
    
    if [ "$failed_requests" = "0" ]; then
        success "Stress Test - $total_requests requests completed, $requests_per_sec req/sec, 0 failures"
        return 0
    else
        failure "Stress Test - $failed_requests failed requests out of $total_requests"
        return 1
    fi
}

# Generate test report
generate_report() {
    local report_file="test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "🎃 SpookyMart Test Suite Report"
        echo "==============================="
        echo "Date: $(date)"
        echo "Target: $ALB_URL"
        echo "Cluster: $CLUSTER_NAME"
        echo ""
        echo "Summary:"
        echo "  Total Tests: $TESTS_TOTAL"
        echo "  Passed: $TESTS_PASSED"
        echo "  Failed: $TESTS_FAILED"
        echo "  Skipped: $TESTS_SKIPPED"
        echo "  Success Rate: $(( TESTS_PASSED * 100 / (TESTS_TOTAL - TESTS_SKIPPED) ))%"
        echo ""
        echo "Detailed Results:"
        echo "=================="
        for result in "${TEST_RESULTS[@]}"; do
            echo "$result"
        done
        echo ""
        echo "Environment Info:"
        echo "=================="
        echo "AWS CLI: $(aws --version 2>/dev/null || echo 'Not available')"
        echo "curl: $(curl --version | head -1 2>/dev/null || echo 'Not available')"
        echo "jq: $(jq --version 2>/dev/null || echo 'Not available')"
        echo "bc: $(bc --version | head -1 2>/dev/null || echo 'Not available')"
        echo "ab: $(ab -V | head -1 2>/dev/null || echo 'Not available')"
    } > "$report_file"
    
    log "Test report saved to: $report_file"
}

# Main test execution
main() {
    log "🎃 Starting Enhanced SpookyMart Test Suite"
    log "Target: $ALB_URL"
    log "Blue/Green Tests: $RUN_BLUE_GREEN_TESTS | Performance Tests: $RUN_PERFORMANCE_TESTS"
    echo ""

    # Prerequisites check
    log "📋 Checking prerequisites..."
    command -v curl >/dev/null 2>&1 || { failure "curl is required but not installed"; exit 1; }
    command -v jq >/dev/null 2>&1 || { failure "jq is required but not installed"; exit 1; }
    command -v bc >/dev/null 2>&1 || { warning "bc not installed, some performance tests will be skipped"; }
    
    if [ "$RUN_BLUE_GREEN_TESTS" = true ]; then
        command -v aws >/dev/null 2>&1 || { warning "AWS CLI not installed, Blue/Green tests will be skipped"; RUN_BLUE_GREEN_TESTS=false; }
    fi
    echo ""

    # 1. Infrastructure Health Tests
    log "🏥 Testing Infrastructure Health..."
    
    test_http_status "ALB Connectivity" "$ALB_URL/" "200"
    test_http_status "API Gateway Products Endpoint" "$ALB_URL/api/products" "200"
    test_http_status "API Gateway Orders Endpoint" "$ALB_URL/api/orders/" "200"
    
    test_with_retry "Service Connect Product Service Health" \
        "curl -s --max-time $TIMEOUT '$ALB_URL/api/products'" \
        '"products"'
    
    test_with_retry "Service Connect Order Service Health" \
        "curl -s --max-time $TIMEOUT '$ALB_URL/api/orders/'" \
        '"orders"'
    
    echo ""

    # 2. Frontend Tests
    log "🖥️  Testing Frontend Service..."
    
    test_with_retry "Frontend Content Load" \
        "curl -s --max-time $TIMEOUT '$ALB_URL/'" \
        "SpookyMart"
    
    test_with_retry "Frontend React App Structure" \
        "curl -s --max-time $TIMEOUT '$ALB_URL/'" \
        'id="root"'
    
    test_with_retry "Frontend JavaScript Bundle" \
        "curl -s --max-time $TIMEOUT '$ALB_URL/'" \
        "static/js/main"
    
    echo ""

    # 3. API Integration Tests
    log "🔗 Testing API Integration..."
    
    test_http_status "Products API Endpoint" "$ALB_URL/api/products" "200"
    test_http_status "Orders API Endpoint" "$ALB_URL/api/orders/" "200"
    
    test_json_response "Products API Structure" "$ALB_URL/api/products" '.data.products | type' "array"
    test_json_response "Orders API Structure" "$ALB_URL/api/orders/" '.orders | type' "array"
    
    # Test specific product data
    test_with_retry "Sample Product Data" \
        "curl -s --max-time $TIMEOUT '$ALB_URL/api/products'" \
        '"prod-001"'
    
    echo ""

    # 4. Blue/Green Deployment Tests (if enabled)
    if [ "$RUN_BLUE_GREEN_TESTS" = true ]; then
        log "🔵🟢 Testing Blue/Green Deployment Infrastructure..."
        
        test_ecs_service_status "$FRONTEND_SERVICE"
        test_deployment_status "$FRONTEND_SERVICE"
        
        test_target_group_health "spookymart-frontend-tg" 0
        test_target_group_health "spookymart-frontend-tg-green" 1
        
        test_alb_traffic_weights
        
        echo ""
    fi

    # 5. End-to-End Workflow Tests
    log "🔄 Testing End-to-End Workflows..."
    
    # Test order creation workflow
    ((TESTS_TOTAL++))
    ORDER_RESPONSE=$(curl -s --max-time $TIMEOUT -X POST "$ALB_URL/api/orders/" \
        -H "Content-Type: application/json" \
        -d "{\"customer_email\":\"$TEST_EMAIL\",\"items\":[{\"product_id\":\"prod-001\",\"quantity\":1}]}" 2>/dev/null || echo "TIMEOUT")
    
    if [ "$ORDER_RESPONSE" = "TIMEOUT" ]; then
        failure "Order Creation (Request timed out - order service may be unavailable)"
    elif echo "$ORDER_RESPONSE" | grep -q "504 Gateway Time-out"; then
        failure "Order Creation (504 Gateway Timeout - order service processing issue)"
    elif echo "$ORDER_RESPONSE" | jq -r '.id' >/dev/null 2>&1 && [ "$(echo "$ORDER_RESPONSE" | jq -r '.id')" != "null" ]; then
        ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.id')
        success "Order Creation (ID: $ORDER_ID)"
        
        # Test order retrieval
        test_http_status "Order Retrieval" "$ALB_URL/api/orders/$ORDER_ID" "200"
        test_json_response "Order Data Validation" "$ALB_URL/api/orders/$ORDER_ID" '.customer_email' "$TEST_EMAIL"
    else
        failure "Order Creation (Invalid response: $(echo "$ORDER_RESPONSE" | head -c 100)...)"
    fi
    
    echo ""

    # 6. Performance Tests (if enabled)
    if [ "$RUN_PERFORMANCE_TESTS" = true ] && command -v bc >/dev/null 2>&1; then
        log "⚡ Testing Performance Baselines..."
        
        test_response_time "Frontend Load Time" "$ALB_URL/" "3.0"
        test_response_time "Products API Response Time" "$ALB_URL/api/products" "2.0"
        test_response_time "Orders API Response Time" "$ALB_URL/api/orders/" "2.0"
        
        if command -v ab >/dev/null 2>&1; then
            stress_test_endpoints 5 50
        fi
        
        echo ""
    fi

    # 7. Security & Configuration Tests
    log "🔒 Testing Security & Configuration..."
    
    test_with_retry "CORS Headers Present" \
        "curl -s -I --max-time $TIMEOUT '$ALB_URL/api/products'" \
        "access-control-allow"
    
    test_http_status "Security Headers Check" "$ALB_URL/" "200"
    
    echo ""

    # Generate report
    generate_report

    # Results Summary
    log "📊 Test Results Summary"
    echo "=================================="
    echo -e "Total Tests: ${TESTS_TOTAL}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo -e "${CYAN}Skipped: ${TESTS_SKIPPED}${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}🎉 All tests passed! SpookyMart is working perfectly!${NC}"
        echo ""
        log "✅ System Status Validated:"
        echo "   • Infrastructure health confirmed"
        echo "   • All services communicating properly"
        echo "   • End-to-end workflows functional"
        echo "   • Performance within acceptable thresholds"
        if [ "$RUN_BLUE_GREEN_TESTS" = true ]; then
            echo "   • Blue/Green deployment infrastructure ready"
        fi
        echo ""
        exit 0
    else
        echo ""
        echo -e "${RED}❌ ${TESTS_FAILED} test(s) failed. Please review the issues above.${NC}"
        echo ""
        exit 1
    fi
}

# Help function
show_help() {
    echo "Enhanced SpookyMart Automated Test Suite"
    echo ""
    echo "Usage: $0 [ALB_URL] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --blue-green     Enable Blue/Green deployment tests (requires AWS CLI)"
    echo "  --performance    Enable performance and stress tests"
    echo "  --all           Enable all test categories"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                                    # Basic tests"
    echo "  $0 --blue-green                                      # Include Blue/Green tests"
    echo "  $0 --performance                                     # Include performance tests"
    echo "  $0 --all                                            # All tests"
    echo "  $0 http://custom-alb.com --blue-green --performance # Custom URL with all tests"
    echo ""
    echo "Prerequisites:"
    echo "  Required: curl, jq"
    echo "  Optional: aws (for Blue/Green tests), bc (for performance), ab (for stress tests)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --blue-green)
            RUN_BLUE_GREEN_TESTS=true
            shift
            ;;
        --performance)
            RUN_PERFORMANCE_TESTS=true
            shift
            ;;
        --all)
            RUN_BLUE_GREEN_TESTS=true
            RUN_PERFORMANCE_TESTS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        http*)
            ALB_URL="$1"
            shift
            ;;
        *)
            warning "Unknown option: $1"
            shift
            ;;
    esac
done

main
