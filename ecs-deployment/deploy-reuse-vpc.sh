#!/bin/bash

# SpookyMart ECS Deployment Script - Reuse Existing VPC
# This script reuses existing VPC infrastructure and deploys the SpookyMart backend services to Amazon ECS

set -e

# Configuration
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID=""  # Will be auto-detected
CLUSTER_NAME="spookymart-cluster"

# Command line options
CREATE_ALB=false
if [[ "$*" == *"--with-alb"* ]]; then
    CREATE_ALB=true
fi

# Resource names to look for
VPC_NAME="spookymart-vpc"
ALB_SG_NAME="spookymart-alb-sg"
ECS_SG_NAME="spookymart-ecs-sg"

# Variables to be populated during deployment
VPC_ID=""
PUBLIC_SUBNET_1_ID=""
PUBLIC_SUBNET_2_ID=""
ALB_SG_ID=""
ECS_SG_ID=""
ALB_DNS_NAME=""
TARGET_GROUP_ARN=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Auto-detect AWS Account ID
detect_aws_config() {
    print_status "Auto-detecting AWS configuration..."
    
    # Get AWS Account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Failed to detect AWS Account ID. Please ensure AWS CLI is configured."
        exit 1
    fi
    
    print_success "Detected AWS Account ID: $AWS_ACCOUNT_ID"
    print_success "Using AWS Region: $AWS_REGION"
}

# Find existing VPC and subnets
find_existing_infrastructure() {
    print_status "Looking for existing VPC infrastructure..."
    
    # Find VPC by name
    VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[0].VpcId' --output text)
    
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_error "Could not find existing VPC with name: $VPC_NAME"
        print_error "Please run the full deployment script first or create the VPC manually"
        exit 1
    fi
    
    print_success "Found existing VPC: $VPC_ID ($VPC_NAME)"
    
    # Find public subnets
    PUBLIC_SUBNETS=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=spookymart-public-subnet-*" --query 'Subnets[*].SubnetId' --output text)
    
    if [ -z "$PUBLIC_SUBNETS" ]; then
        print_error "Could not find public subnets in VPC: $VPC_ID"
        exit 1
    fi
    
    # Convert to array
    PUBLIC_SUBNET_ARRAY=($PUBLIC_SUBNETS)
    PUBLIC_SUBNET_1_ID=${PUBLIC_SUBNET_ARRAY[0]}
    PUBLIC_SUBNET_2_ID=${PUBLIC_SUBNET_ARRAY[1]}
    
    print_success "Found public subnets: $PUBLIC_SUBNET_1_ID, $PUBLIC_SUBNET_2_ID"
    
    # Find security groups
    ALB_SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$ALB_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
    ECS_SG_ID=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$ECS_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
    
    if [ "$ALB_SG_ID" = "None" ] || [ -z "$ALB_SG_ID" ]; then
        print_warning "ALB security group not found, will create it"
        ALB_SG_ID=""
    else
        print_success "Found ALB security group: $ALB_SG_ID"
    fi
    
    if [ "$ECS_SG_ID" = "None" ] || [ -z "$ECS_SG_ID" ]; then
        print_warning "ECS security group not found, will create it"
        ECS_SG_ID=""
    else
        print_success "Found ECS security group: $ECS_SG_ID"
    fi
}

# Create missing security groups
create_missing_security_groups() {
    print_status "Checking and creating missing security groups..."
    
    # Create ALB security group if missing
    if [ -z "$ALB_SG_ID" ]; then
        print_status "Creating ALB security group..."
        ALB_SG_ID=$(aws ec2 create-security-group \
            --group-name "$ALB_SG_NAME" \
            --description "Security group for SpookyMart Application Load Balancer" \
            --vpc-id "$VPC_ID" \
            --region "$AWS_REGION" \
            --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$ALB_SG_NAME}]" \
            --query 'GroupId' \
            --output text)
        
        # Configure ALB security group rules
        aws ec2 authorize-security-group-ingress \
            --group-id "$ALB_SG_ID" \
            --protocol tcp \
            --port 80 \
            --cidr "0.0.0.0/0" \
            --region "$AWS_REGION"
        
        aws ec2 authorize-security-group-ingress \
            --group-id "$ALB_SG_ID" \
            --protocol tcp \
            --port 443 \
            --cidr "0.0.0.0/0" \
            --region "$AWS_REGION"
        
        print_success "Created ALB security group: $ALB_SG_ID"
    fi
    
    # Create ECS security group if missing
    if [ -z "$ECS_SG_ID" ]; then
        print_status "Creating ECS security group..."
        ECS_SG_ID=$(aws ec2 create-security-group \
            --group-name "$ECS_SG_NAME" \
            --description "Security group for SpookyMart ECS services" \
            --vpc-id "$VPC_ID" \
            --region "$AWS_REGION" \
            --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$ECS_SG_NAME}]" \
            --query 'GroupId' \
            --output text)
        
        # Configure ECS security group rules - Allow direct internet access for testing
        aws ec2 authorize-security-group-ingress \
            --group-id "$ECS_SG_ID" \
            --protocol tcp \
            --port 3000 \
            --cidr "0.0.0.0/0" \
            --region "$AWS_REGION"
        
        aws ec2 authorize-security-group-ingress \
            --group-id "$ECS_SG_ID" \
            --protocol tcp \
            --port 3001 \
            --cidr "0.0.0.0/0" \
            --region "$AWS_REGION"
        
        aws ec2 authorize-security-group-ingress \
            --group-id "$ECS_SG_ID" \
            --protocol tcp \
            --port 3002 \
            --cidr "0.0.0.0/0" \
            --region "$AWS_REGION"
        
        # Allow ECS services to communicate with each other
        aws ec2 authorize-security-group-ingress \
            --group-id "$ECS_SG_ID" \
            --protocol tcp \
            --port 3000 \
            --source-group "$ECS_SG_ID" \
            --region "$AWS_REGION"
        
        aws ec2 authorize-security-group-ingress \
            --group-id "$ECS_SG_ID" \
            --protocol tcp \
            --port 3001 \
            --source-group "$ECS_SG_ID" \
            --region "$AWS_REGION"
        
        aws ec2 authorize-security-group-ingress \
            --group-id "$ECS_SG_ID" \
            --protocol tcp \
            --port 3002 \
            --source-group "$ECS_SG_ID" \
            --region "$AWS_REGION"
        
        print_success "Created ECS security group: $ECS_SG_ID"
    fi
}

# Create ECR repositories
create_ecr_repos() {
    print_status "Creating ECR repositories..."
    
    services=("spookymart-product-service" "spookymart-order-service" "spookymart-api-gateway")
    
    for service in "${services[@]}"; do
        if aws ecr describe-repositories --repository-names "$service" --region "$AWS_REGION" >/dev/null 2>&1; then
            print_warning "ECR repository $service already exists"
        else
            aws ecr create-repository --repository-name "$service" --region "$AWS_REGION"
            print_success "Created ECR repository: $service"
        fi
    done
}

# Build and push Docker images
build_and_push() {
    print_status "Building and pushing Docker images..."
    
    # Get ECR login token
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Build and push each service
    services=("product-service" "order-service" "api-gateway")
    
    for service in "${services[@]}"; do
        print_status "Building $service..."
        
        # Build image
        docker build -t "spookymart-$service" "../$service/"
        
        # Tag for ECR
        docker tag "spookymart-$service:latest" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/spookymart-$service:latest"
        
        # Push to ECR
        docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/spookymart-$service:latest"
        
        print_success "Pushed $service to ECR"
    done
}

# Create ECS cluster
create_cluster() {
    print_status "Creating ECS cluster..."
    
    if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" | grep -q "ACTIVE"; then
        print_warning "ECS cluster $CLUSTER_NAME already exists"
    else
        aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION"
        print_success "Created ECS cluster: $CLUSTER_NAME"
    fi
}

# Create CloudWatch log groups
create_log_groups() {
    print_status "Creating CloudWatch log groups..."
    
    log_groups=("/ecs/spookymart-product-service" "/ecs/spookymart-order-service" "/ecs/spookymart-api-gateway")
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$AWS_REGION" | grep -q "$log_group"; then
            print_warning "Log group $log_group already exists"
        else
            aws logs create-log-group --log-group-name "$log_group" --region "$AWS_REGION"
            print_success "Created log group: $log_group"
        fi
    done
}

# Update task definitions with account ID and region
update_task_definitions() {
    print_status "Updating task definitions..."
    
    services=("product-service" "order-service" "api-gateway")
    
    for service in "${services[@]}"; do
        # Create a temporary file with updated values
        sed "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g; s/REGION/$AWS_REGION/g" \
            "$service-task-definition.json" > "tmp-$service-task-definition.json"
        
        print_success "Updated task definition for $service"
    done
}

# Register task definitions
register_task_definitions() {
    print_status "Registering task definitions..."
    
    services=("product-service" "order-service" "api-gateway")
    
    for service in "${services[@]}"; do
        aws ecs register-task-definition \
            --cli-input-json "file://tmp-$service-task-definition.json" \
            --region "$AWS_REGION"
        
        print_success "Registered task definition for spookymart-$service"
        
        # Clean up temporary file
        rm "tmp-$service-task-definition.json"
    done
}

# Create ECS services
create_services() {
    print_status "Creating ECS services..."
    
    services=("product-service" "order-service" "api-gateway")
    SUBNET_IDS="$PUBLIC_SUBNET_1_ID,$PUBLIC_SUBNET_2_ID"
    
    print_status "Using subnets: $SUBNET_IDS"
    print_status "Using security group: $ECS_SG_ID"
    
    for service in "${services[@]}"; do
        service_name="spookymart-$service"
        
        print_status "Checking if service $service_name already exists..."
        if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service_name" --region "$AWS_REGION" 2>/dev/null | grep -q "ACTIVE"; then
            print_warning "ECS service $service_name already exists"
        else
            print_status "Creating ECS service: $service_name"
            
            # Create service with error handling
            if aws ecs create-service \
                --cluster "$CLUSTER_NAME" \
                --service-name "$service_name" \
                --task-definition "$service_name" \
                --desired-count 1 \
                --launch-type FARGATE \
                --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$ECS_SG_ID],assignPublicIp=ENABLED}" \
                --region "$AWS_REGION" >/dev/null 2>&1; then
                print_success "Created ECS service: $service_name"
            else
                print_error "Failed to create ECS service: $service_name"
                print_status "Continuing with next service..."
            fi
        fi
    done
}

# Wait for services to be stable
wait_for_services() {
    print_status "Waiting for services to become stable (this may take a few minutes)..."
    
    services=("spookymart-product-service" "spookymart-order-service" "spookymart-api-gateway")
    
    for service in "${services[@]}"; do
        print_status "Checking if service $service exists..."
        
        # Check if service exists first
        if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" 2>/dev/null | grep -q "serviceName"; then
            print_status "Waiting for $service to be stable (timeout: 10 minutes)..."
            
            # Use timeout to prevent hanging indefinitely
            if timeout 600 aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$service" --region "$AWS_REGION" 2>/dev/null; then
                print_success "$service is now stable"
            else
                print_warning "$service did not become stable within 10 minutes, but continuing..."
            fi
        else
            print_warning "Service $service does not exist, skipping stability check"
        fi
    done
}

# Create Application Load Balancer
create_alb() {
    if [ "$CREATE_ALB" = false ]; then
        return 0
    fi
    
    print_status "Creating Application Load Balancer..."
    
    ALB_NAME="spookymart-alb"
    TARGET_GROUP_NAME="spookymart-api-tg"
    
    # Check if ALB already exists
    ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
    
    if [ "$ALB_ARN" != "None" ] && [ "$ALB_ARN" != "" ]; then
        print_warning "ALB $ALB_NAME already exists: $ALB_ARN"
        ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text --region "$AWS_REGION")
    else
        # Create ALB
        ALB_ARN=$(aws elbv2 create-load-balancer \
            --name "$ALB_NAME" \
            --subnets "$PUBLIC_SUBNET_1_ID" "$PUBLIC_SUBNET_2_ID" \
            --security-groups "$ALB_SG_ID" \
            --scheme internet-facing \
            --type application \
            --ip-address-type ipv4 \
            --tags Key=Name,Value="$ALB_NAME" \
            --region "$AWS_REGION" \
            --query 'LoadBalancers[0].LoadBalancerArn' \
            --output text)
        
        ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text --region "$AWS_REGION")
        
        print_success "Created ALB: $ALB_ARN"
        print_success "ALB DNS Name: $ALB_DNS_NAME"
    fi
    
    # Create target group
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
    
    if [ "$TARGET_GROUP_ARN" != "None" ] && [ "$TARGET_GROUP_ARN" != "" ]; then
        print_warning "Target Group $TARGET_GROUP_NAME already exists: $TARGET_GROUP_ARN"
    else
        TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
            --name "$TARGET_GROUP_NAME" \
            --protocol HTTP \
            --port 3000 \
            --vpc-id "$VPC_ID" \
            --target-type ip \
            --health-check-enabled \
            --health-check-path "/health" \
            --health-check-protocol HTTP \
            --health-check-port 3000 \
            --health-check-interval-seconds 30 \
            --health-check-timeout-seconds 5 \
            --healthy-threshold-count 2 \
            --unhealthy-threshold-count 3 \
            --tags Key=Name,Value="$TARGET_GROUP_NAME" \
            --region "$AWS_REGION" \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text)
        
        print_success "Created Target Group: $TARGET_GROUP_ARN"
    fi
    
    # Create listener
    LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[0].ListenerArn' --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
    
    if [ "$LISTENER_ARN" != "None" ] && [ "$LISTENER_ARN" != "" ]; then
        print_warning "ALB Listener already exists: $LISTENER_ARN"
    else
        LISTENER_ARN=$(aws elbv2 create-listener \
            --load-balancer-arn "$ALB_ARN" \
            --protocol HTTP \
            --port 80 \
            --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
            --region "$AWS_REGION" \
            --query 'Listeners[0].ListenerArn' \
            --output text)
        
        print_success "Created ALB Listener: $LISTENER_ARN"
    fi
}

# Register API Gateway with ALB
register_alb_targets() {
    if [ "$CREATE_ALB" = false ]; then
        return 0
    fi
    
    print_status "Registering API Gateway with ALB..."
    
    # Get API Gateway task IP
    TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "spookymart-api-gateway" --region "$AWS_REGION" --query 'taskArns[0]' --output text)
    
    if [ "$TASK_ARN" != "None" ] && [ "$TASK_ARN" != "" ]; then
        TASK_IP=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --region "$AWS_REGION" --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' --output text)
        
        if [ "$TASK_IP" != "None" ] && [ "$TASK_IP" != "" ]; then
            # Register target
            aws elbv2 register-targets \
                --target-group-arn "$TARGET_GROUP_ARN" \
                --targets Id="$TASK_IP",Port=3000 \
                --region "$AWS_REGION"
            
            print_success "Registered API Gateway task IP $TASK_IP with ALB"
            
            # Wait for target to become healthy
            print_status "Waiting for target to become healthy (this may take 2-3 minutes)..."
            sleep 120
            
            # Test ALB endpoint
            print_status "Testing ALB endpoint..."
            if curl -f "http://$ALB_DNS_NAME/health" >/dev/null 2>&1; then
                print_success "ALB health check passed!"
            else
                print_warning "ALB health check failed - target may still be initializing"
            fi
        else
            print_warning "Could not get API Gateway task IP address"
        fi
    else
        print_warning "No running tasks found for API Gateway service"
    fi
}

# Get service endpoints
get_endpoints() {
    print_status "Getting service endpoints..."
    
    services=("spookymart-product-service" "spookymart-order-service" "spookymart-api-gateway")
    
    for service in "${services[@]}"; do
        # Get task ARN
        task_arn=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$service" --region "$AWS_REGION" --query 'taskArns[0]' --output text)
        
        if [ "$task_arn" != "None" ] && [ "$task_arn" != "" ]; then
            # Get task details
            public_ip=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task_arn" --region "$AWS_REGION" --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --region "$AWS_REGION" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
            
            if [ "$public_ip" != "None" ] && [ "$public_ip" != "" ]; then
                case $service in
                    "spookymart-product-service")
                        echo -e "${GREEN}Product Service:${NC} http://$public_ip:3001"
                        echo -e "${GREEN}Product Health:${NC} http://$public_ip:3001/health"
                        ;;
                    "spookymart-order-service")
                        echo -e "${GREEN}Order Service:${NC} http://$public_ip:3002"
                        echo -e "${GREEN}Order Health:${NC} http://$public_ip:3002/health"
                        ;;
                    "spookymart-api-gateway")
                        echo -e "${GREEN}API Gateway:${NC} http://$public_ip:3000"
                        echo -e "${GREEN}API Health:${NC} http://$public_ip:3000/health"
                        ;;
                esac
            fi
        fi
    done
    
    # Show ALB endpoints if created
    if [ "$CREATE_ALB" = true ] && [ -n "$ALB_DNS_NAME" ]; then
        echo ""
        print_status "🚀 Application Load Balancer Endpoints:"
        echo -e "${GREEN}SpookyMart API (via ALB):${NC} http://$ALB_DNS_NAME"
        echo -e "${GREEN}API Health Check:${NC} http://$ALB_DNS_NAME/health"
        echo -e "${GREEN}Products API:${NC} http://$ALB_DNS_NAME/api/products"
        echo -e "${GREEN}Orders API:${NC} http://$ALB_DNS_NAME/api/orders"
    fi
}

# Main deployment function
main() {
    echo "🎃 SpookyMart ECS Deployment Script (Reuse VPC) 🎃"
    echo "=================================================="
    echo ""
    
    detect_aws_config
    find_existing_infrastructure
    create_missing_security_groups
    create_ecr_repos
    build_and_push
    create_cluster
    create_log_groups
    update_task_definitions
    register_task_definitions
    create_services
    wait_for_services
    create_alb
    register_alb_targets
    
    echo ""
    print_success "🎉 Deployment completed successfully!"
    echo ""
    print_status "Using existing infrastructure:"
    echo -e "${GREEN}VPC:${NC} $VPC_ID ($VPC_NAME)"
    echo -e "${GREEN}Public Subnets:${NC} $PUBLIC_SUBNET_1_ID, $PUBLIC_SUBNET_2_ID"
    echo -e "${GREEN}Security Groups:${NC} $ALB_SG_ID (ALB), $ECS_SG_ID (ECS)"
    echo ""
    print_status "Service endpoints:"
    get_endpoints
    
    echo ""
    print_status "Next steps:"
    echo "1. Test the deployed services using the provided endpoints"
    echo "2. Use the ALB endpoint for production traffic"
    echo "3. Consider implementing CI/CD pipeline for automated deployments"
}

# Run main function
main "$@"
