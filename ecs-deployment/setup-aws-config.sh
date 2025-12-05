#!/bin/bash

# SpookyMart AWS Configuration Setup Script
# This script helps you verify AWS configuration before running the deployment

set -e

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

echo "🎃 SpookyMart AWS Configuration Verification 🎃"
echo "=============================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured. Please run 'aws configure' first."
    exit 1
fi

print_success "AWS CLI is installed and configured"
echo ""

# Get AWS Account ID
print_status "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "AWS Account ID: $AWS_ACCOUNT_ID"

# Get AWS Region
print_status "Getting current AWS region..."
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-west-2"
    print_warning "No region configured, using default: $AWS_REGION"
    print_status "You can change this by running: aws configure set region <your-preferred-region>"
else
    print_success "AWS Region: $AWS_REGION"
fi

# Check Docker availability
print_status "Checking Docker availability..."
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        print_success "Docker is installed and running"
    else
        print_error "Docker is installed but not running. Please start Docker Desktop."
        exit 1
    fi
else
    print_error "Docker is not installed. Please install Docker Desktop:"
    echo "https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Check required AWS permissions
print_status "Checking AWS permissions..."
PERMISSIONS_OK=true

# Check ECR permissions
if aws ecr describe-repositories --region "$AWS_REGION" &> /dev/null; then
    print_success "✓ ECR permissions verified"
else
    print_error "✗ ECR permissions missing"
    PERMISSIONS_OK=false
fi

# Check ECS permissions
if aws ecs list-clusters --region "$AWS_REGION" &> /dev/null; then
    print_success "✓ ECS permissions verified"
else
    print_error "✗ ECS permissions missing"
    PERMISSIONS_OK=false
fi

# Check EC2 permissions (for VPC creation)
if aws ec2 describe-vpcs --region "$AWS_REGION" &> /dev/null; then
    print_success "✓ EC2/VPC permissions verified"
else
    print_error "✗ EC2/VPC permissions missing"
    PERMISSIONS_OK=false
fi

# Check CloudWatch Logs permissions
if aws logs describe-log-groups --region "$AWS_REGION" &> /dev/null; then
    print_success "✓ CloudWatch Logs permissions verified"
else
    print_error "✗ CloudWatch Logs permissions missing"
    PERMISSIONS_OK=false
fi

echo ""
echo "🎯 Configuration Summary:"
echo "========================"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Docker: Available"
echo ""

if [ "$PERMISSIONS_OK" = true ]; then
    print_success "✅ All prerequisites met! The deployment script will:"
    echo ""
    echo "   🏗️  Create dedicated VPC infrastructure:"
    echo "      • VPC: spookymart-vpc (10.0.0.0/16)"
    echo "      • Public Subnets: spookymart-public-subnet-1, spookymart-public-subnet-2"
    echo "      • Private Subnets: spookymart-private-subnet-1, spookymart-private-subnet-2"
    echo "      • Internet Gateway: spookymart-igw"
    echo "      • Security Groups: spookymart-alb-sg, spookymart-ecs-sg"
    echo ""
    echo "   🐳 Create ECR repositories and push Docker images"
    echo "   ⚙️  Create ECS cluster and deploy services"
    echo "   📊 Set up CloudWatch logging"
    echo ""
    print_status "Ready to deploy! Run the following commands:"
    echo "   cd ecs-deployment"
    echo "   chmod +x deploy.sh"
    echo "   ./deploy.sh"
else
    print_error "❌ Missing required AWS permissions. Please ensure your AWS user/role has:"
    echo "   • AmazonECS_FullAccess"
    echo "   • AmazonEC2FullAccess (for VPC creation)"
    echo "   • AmazonECRFullAccess"
    echo "   • CloudWatchLogsFullAccess"
    echo ""
    echo "   Or create a custom policy with the required permissions."
fi

echo ""
print_status "💰 Estimated AWS costs for this deployment: ~\$15-30/month"
echo "   • ECS Fargate tasks: ~\$10-20/month"
echo "   • NAT Gateway (if added): ~\$45/month"
echo "   • Data transfer: ~\$1-5/month"
echo ""
print_status "📚 See DEPLOYMENT_GUIDE.md for detailed information"
