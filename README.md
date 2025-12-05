# SpookyMart E-Commerce Platform

A microservices-based e-commerce platform for Halloween products, built with modern cloud-native architecture and deployed on AWS ECS.

## 🏗️ Architecture Overview

SpookyMart consists of four core microservices:

```
┌─────────────┐
│   Frontend  │ (React/TypeScript - Port 3000)
└──────┬──────┘
       │
┌──────▼──────┐
│ API Gateway │ (Node.js/Express - Port 3003)
└──────┬──────┘
       │
       ├─────────────┬─────────────┐
       │             │             │
┌──────▼──────┐ ┌───▼────────┐ ┌──▼────────┐
│   Product   │ │   Order    │ │  Payment  │
│   Service   │ │  Service   │ │  Service  │
└─────────────┘ └────────────┘ └───────────┘
  (Node.js)      (Python/FastAPI)  (Future)
  Port 3001         Port 3002
```

### Service Details

#### 1. Frontend Service (`frontend-service/`)
- **Technology**: React 18, TypeScript, Nginx
- **Port**: 3000
- **Features**:
  - Product catalog browsing
  - Shopping cart management
  - Order checkout
  - Responsive UI

#### 2. API Gateway (`api-gateway/`)
- **Technology**: Node.js, Express
- **Port**: 3003
- **Responsibilities**:
  - Request routing to backend services
  - Request/response aggregation
  - Service health monitoring
  - Centralized logging

#### 3. Product Service (`product-service/`)
- **Technology**: Node.js, Express
- **Port**: 3001
- **Features**:
  - Product catalog management
  - Product search and filtering
  - Inventory management
  - RESTful API

#### 4. Order Service (`order-service/`)
- **Technology**: Python, FastAPI
- **Port**: 3002
- **Features**:
  - Order creation and management
  - Order status tracking
  - Integration with product service
  - Async processing with Python

## 🚀 Quick Start

### Prerequisites

**Required:**
- Docker Desktop or Docker Engine + Docker Compose
- Git

**For Local Development:**
- Node.js 18+ (for JavaScript services)
- Python 3.11+ (for order service)
- npm or yarn

**For AWS Deployment:**
- AWS CLI configured
- AWS account with ECS, VPC, ALB permissions
- ECR repositories created

### Option 1: Docker Compose (Recommended for Testing)

1. **Clone and start all services:**
   ```bash
   git clone <repository-url>
   cd spookymart-ecommerce
   docker-compose up --build
   ```

2. **Access the application:**
   - Frontend: http://localhost:3000
   - API Gateway: http://localhost:3003
   - Product Service: http://localhost:3001
   - Order Service: http://localhost:3002

3. **Stop services:**
   ```bash
   docker-compose down
   ```

### Option 2: Local Development (Individual Services)

#### Product Service
```bash
cd product-service
npm install
npm start
```

#### Order Service
```bash
cd order-service
pip install -r requirements.txt
python main.py
```

#### API Gateway
```bash
cd api-gateway
npm install
npm start
```

#### Frontend Service
```bash
cd frontend-service
npm install
npm start
# For production build:
npm run build
```

## 🧪 Testing

### Automated Test Suite

Run the comprehensive test suite to validate all services:

```bash
# Make executable (first time only)
chmod +x test-suite-enhanced.sh

# Test local Docker environment
./test-suite-enhanced.sh

# Test deployed ECS environment
./test-suite-enhanced.sh http://your-alb-dns-name
```

### Test Configuration

Customize tests via `test-config.yaml`:
```yaml
base_url: "http://localhost:3003"
timeout: 30
max_retries: 3
health_check_interval: 5
```

### Manual Testing

#### Test Product Service
```bash
# Get all products
curl http://localhost:3001/api/products

# Get specific product
curl http://localhost:3001/api/products/prod-001

# Health check
curl http://localhost:3001/health
```

#### Test Order Service
```bash
# Create an order
curl -X POST http://localhost:3002/api/orders/ \
  -H "Content-Type: application/json" \
  -d '{
    "customer_email": "test@spookymart.com",
    "customer_name": "Test User",
    "items": [{
      "product_id": "prod-001",
      "quantity": 1,
      "unit_price": 49.99
    }]
  }'

# Get all orders
curl http://localhost:3002/api/orders/

# Health check
curl http://localhost:3002/health
```

#### Test via API Gateway
```bash
# Products through gateway
curl http://localhost:3003/api/products

# Orders through gateway
curl -X POST http://localhost:3003/api/orders/ \
  -H "Content-Type: application/json" \
  -d '{"customer_email": "test@example.com", "items": []}'
```

## ☁️ AWS ECS Deployment

### Prerequisites Setup

1. **Configure AWS CLI:**
   ```bash
   aws configure
   # Enter: Access Key, Secret Key, Region (us-east-1), Output format (json)
   ```

2. **Create ECR Repositories:**
   ```bash
   aws ecr create-repository --repository-name spookymart-frontend
   aws ecr create-repository --repository-name spookymart-api-gateway
   aws ecr create-repository --repository-name spookymart-product-service
   aws ecr create-repository --repository-name spookymart-order-service
   ```

### Deployment Options

#### Option 1: Fresh Deployment (New VPC)
```bash
cd ecs-deployment
chmod +x deploy.sh
./deploy.sh
```

Creates:
- New VPC with public subnets
- Application Load Balancer
- ECS Cluster
- All 4 services

#### Option 2: Deploy with Existing VPC
```bash
cd ecs-deployment
chmod +x deploy-reuse-vpc.sh
./deploy-reuse-vpc.sh
```

Reuses existing VPC and creates services.

### Check Deployment Status

```bash
cd ecs-deployment
chmod +x check-deployment.sh
./check-deployment.sh
```

### Deployment Process

The deployment script will:
1. Build Docker images for all services
2. Tag and push images to ECR
3. Create/update ECS task definitions
4. Create ECS cluster (if new)
5. Deploy services with health checks
6. Configure Application Load Balancer
7. Output ALB DNS name for access

### Post-Deployment

Access your application at:
```
http://<ALB-DNS-NAME>
```

View logs in CloudWatch:
```
Log Groups:
- /ecs/spookymart-frontend
- /ecs/spookymart-api-gateway
- /ecs/spookymart-product-service
- /ecs/spookymart-order-service
```

## 📁 Project Structure

```
spookymart-ecommerce/
├── api-gateway/              # API Gateway service
│   ├── server.js            # Express server
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
├── product-service/          # Product catalog service
│   ├── server.js
│   ├── routes/
│   ├── models/
│   ├── data/
│   ├── Dockerfile
│   └── package.json
├── order-service/            # Order processing service
│   ├── main.py              # FastAPI application
│   ├── routes/
│   ├── models/
│   ├── services/
│   ├── Dockerfile
│   └── requirements.txt
├── frontend-service/         # React frontend
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── package.json
├── ecs-deployment/           # AWS ECS deployment scripts
│   ├── deploy.sh
│   ├── deploy-reuse-vpc.sh
│   ├── check-deployment.sh
│   └── *-task-definition.json
├── docker-compose.yml        # Local development
├── test-suite-enhanced.sh    # Automated tests
└── test-config.yaml          # Test configuration
```

## 🔧 Configuration

### Environment Variables

#### Product Service
```bash
PORT=3001
NODE_ENV=production
```

#### Order Service
```bash
PORT=3002
ENVIRONMENT=production
PRODUCT_SERVICE_URL=http://product-service:3001
```

#### API Gateway
```bash
PORT=3003
PRODUCT_SERVICE_URL=http://product-service:3001
ORDER_SERVICE_URL=http://order-service:3002
```

### Service Discovery

Services communicate via:
- **Local/Docker**: Service names as hostnames
- **ECS**: AWS Cloud Map for service discovery

## 🛠️ Development Workflow

### Adding New Features

1. **Create feature branch:**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Make changes to service code**

3. **Test locally:**
   ```bash
   docker-compose up --build
   ./test-suite-enhanced.sh
   ```

4. **Commit and push:**
   ```bash
   git add .
   git commit -m "Add new feature"
   git push origin feature/new-feature
   ```

5. **Deploy to ECS:**
   ```bash
   cd ecs-deployment
   ./deploy-reuse-vpc.sh
   ```

### Debugging

#### View Docker Logs
```bash
docker-compose logs -f <service-name>
# Example: docker-compose logs -f order-service
```

#### View ECS Logs
```bash
aws logs tail /ecs/spookymart-order-service --follow
```

#### Check Service Health
```bash
curl http://localhost:3001/health  # Product Service
curl http://localhost:3002/health  # Order Service
curl http://localhost:3003/health  # API Gateway
```

## 📊 Monitoring & Observability

### Health Checks

All services expose `/health` endpoints:
- Returns service status
- Dependencies health
- Version information

### Logging

- **Format**: Structured JSON logs
- **Local**: Console output
- **ECS**: CloudWatch Logs
- **Retention**: 7 days (configurable)

### Metrics (Future Enhancement)

Consider adding:
- Prometheus for metrics collection
- Grafana for visualization
- CloudWatch metrics for AWS resources

## 🔐 Security Best Practices

1. **Never commit sensitive data**
   - Use AWS Secrets Manager for credentials
   - Use environment variables for configuration

2. **Network Security**
   - Services communicate internally via private subnets
   - Only ALB is internet-facing

3. **Container Security**
   - Use official base images
   - Regular security updates
   - Scan images for vulnerabilities

## 🚧 Known Limitations & Future Enhancements

### Current Limitations
- In-memory data storage (order service)
- No authentication/authorization
- No payment processing
- Single region deployment

### Planned Enhancements
- [ ] Add database (DynamoDB/RDS)
- [ ] Implement user authentication (Cognito)
- [ ] Add payment service
- [ ] Implement caching (Redis/ElastiCache)
- [ ] Add CI/CD pipeline
- [ ] Multi-region deployment
- [ ] Rate limiting
- [ ] API documentation (Swagger/OpenAPI)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Add tests
5. Submit pull request

## 📞 Support

For questions or issues:
- Check existing documentation
- Review CloudWatch logs
- Contact the platform team

## 📝 License

[Add your license information]

---

**Built with ❤️ for Halloween enthusiasts everywhere! 🎃👻**
