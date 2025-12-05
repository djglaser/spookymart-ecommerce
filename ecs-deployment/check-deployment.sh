#!/bin/bash

# SpookyMart ECS Deployment Checker
# This script checks the status of the SpookyMart ECS deployment

set -e

# Configuration
AWS_REGION="us-west-2"
CLUSTER_NAME="spookymart-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🎃 SpookyMart ECS Deployment Status Check 🎃"
echo "============================================="
echo ""

# Check AWS CLI configuration
print_status "Checking AWS CLI configuration..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "ERROR")
if [ "$AWS_ACCOUNT_ID" = "ERROR" ]; then
    print_error "AWS CLI not configured or no permissions"
    exit 1
else
    print_success "AWS Account ID: $AWS_ACCOUNT_ID"
fi

# Check ECS cluster
print_status "Checking ECS cluster..."
if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    cluster_status=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" --query 'clusters[0].status' --output text)
    print_success "ECS cluster $CLUSTER_NAME exists with status: $cluster_status"
else
    print_error "ECS cluster $CLUSTER_NAME not found"
fi

# Check ECR repositories
print_status "Checking ECR repositories..."
services=("spookymart-product-service" "spookymart-order-service" "spookymart-api-gateway")
for service in "${services[@]}"; do
    if aws ecr describe-repositories --repository-names "$service" --region "$AWS_REGION" >/dev/null 2>&1; then
        print_success "ECR repository $service exists"
    else
        print_error "ECR repository $service not found"
    fi
done

# Check task definitions
print_status "Checking task definitions..."
for service in "${services[@]}"; do
    if aws ecs describe-task-definition --task-definition "$service" --region "$AWS_REGION" >/dev/null 2>&1; then
        revision=$(aws ecs describe-task-definition --task-definition "$service" --region "$AWS_REGION" --query 'taskDefinition.revision' --output text)
        print_success "Task definition $service exists (revision: $revision)"
    else
        print_error "Task definition $service not found"
    fi
done

# Check ECS services
print_status "Checking ECS services..."
for service in "${services[@]}"; do
    if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" >/dev/null 2>&1; then
        service_status=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" --query 'services[0].status' --output text)
        desired_count=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" --query 'services[0].desiredCount' --output text)
        running_count=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" --query 'services[0].runningCount' --output text)
        print_success "ECS service $service exists - Status: $service_status, Desired: $desired_count, Running: $running_count"
        
        # Check for service events (errors)
        events=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" --query 'services[0].events[0:3].[createdAt,message]' --output table)
        if [ -n "$events" ]; then
            echo "Recent events for $service:"
            echo "$events"
        fi
    else
        print_error "ECS service $service not found"
    fi
done

# Check running tasks
print_status "Checking running tasks..."
for service in "${services[@]}"; do
    task_arns=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$service" --region "$AWS_REGION" --query 'taskArns' --output text)
    if [ -n "$task_arns" ] && [ "$task_arns" != "None" ]; then
        print_success "Service $service has running tasks"
        for task_arn in $task_arns; do
            task_status=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task_arn" --region "$AWS_REGION" --query 'tasks[0].lastStatus' --output text)
            echo "  Task: $task_arn - Status: $task_status"
        done
    else
        print_warning "Service $service has no running tasks"
    fi
done

# Check VPC resources
print_status "Checking VPC resources..."
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=spookymart-vpc" --region "$AWS_REGION" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$vpc_id" != "None" ] && [ -n "$vpc_id" ]; then
    print_success "SpookyMart VPC exists: $vpc_id"
    
    # Check subnets
    subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=spookymart-*" --region "$AWS_REGION" --query 'Subnets[].{Name:Tags[?Key==`Name`].Value|[0],SubnetId:SubnetId,AvailabilityZone:AvailabilityZone}' --output table)
    echo "SpookyMart subnets:"
    echo "$subnets"
    
    # Check security groups
    security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=spookymart-*" --region "$AWS_REGION" --query 'SecurityGroups[].{Name:Tags[?Key==`Name`].Value|[0],GroupId:GroupId}' --output table)
    echo "SpookyMart security groups:"
    echo "$security_groups"
else
    print_error "SpookyMart VPC not found"
fi

echo ""
print_status "Deployment check completed!"
