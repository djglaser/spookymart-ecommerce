# SpookyMart Team Onboarding Guide

Welcome to the SpookyMart team! This guide will help you get started with the project quickly and effectively.

## 📚 Getting Started Checklist

### Day 1: Environment Setup
- [ ] Clone the repository
- [ ] Install prerequisites (Docker, Node.js, Python)
- [ ] Run `docker-compose up` to verify local setup
- [ ] Run test suite: `./test-suite-enhanced.sh`
- [ ] Access frontend at http://localhost:3000
- [ ] Review this README and architecture overview

### Week 1: Understanding the Architecture
- [ ] Review each service's README
- [ ] Understand the API Gateway routing
- [ ] Study the service communication patterns
- [ ] Review Docker Compose configuration
- [ ] Understand health check mechanisms

### Week 2: Development Workflow
- [ ] Make a small change to a service
- [ ] Test locally with Docker Compose
- [ ] Review deployment scripts
- [ ] Understand ECS deployment process
- [ ] Review CloudWatch logging

## 🎯 Learning Path

### 1. Architecture Understanding

**Start Here:**
- Read the main README.md
- Understand the microservices architecture diagram
- Review each service's purpose and technology stack

**Key Concepts:**
- API Gateway pattern
- Service-to-service communication
- Container orchestration with ECS
- Health checks and monitoring

### 2. Local Development

**Practice Tasks:**
1. Start all services locally
2. Make a test API call to each service
3. View logs from all services
4. Modify a product and see it reflected
5. Create a test order

**Commands to Know:**
```bash
# Start services
docker-compose up --build

# View specific service logs
docker-compose logs -f order-service

# Rebuild single service
docker-compose up -d --build product-service

# Stop all services
docker-compose down
```

### 3. Service Deep Dive

**Product Service (Node.js)**
- Location: `product-service/`
- Key files:
  - `server.js` - Express server setup
  - `routes/products.js` - API endpoints
  - `data/products.json` - Product data
- Practice: Add a new product field

**Order Service (Python/FastAPI)**
- Location: `order-service/`
- Key files:
  - `main.py` - FastAPI application
  - `routes/orders.py` - Order endpoints
  - `models/order.py` - Pydantic models
- Practice: Add order status update endpoint

**API Gateway (Node.js)**
- Location: `api-gateway/`
- Key file: `server.js`
- Practice: Add a new route

**Frontend (React/TypeScript)**
- Location: `frontend-service/`
- Key files:
  - `src/App.tsx` - Main application
  - `src/components/` - React components
  - `src/services/api.ts` - API client
- Practice: Add a new UI component

### 4. Testing

**Learn:**
- How to run the test suite
- How to interpret test results
- How to add new test cases

**Practice:**
```bash
# Run all tests
./test-suite-enhanced.sh

# Test specific endpoint manually
curl http://localhost:3003/api/products
```

### 5. AWS Deployment

**Prerequisites:**
- AWS account access
- AWS CLI configured
- Understanding of ECS concepts

**Learn:**
- ECS task definitions
- Service discovery
- Load balancer configuration
- CloudWatch Logs

**Practice:**
```bash
# Deploy to ECS (after AWS setup)
cd ecs-deployment
./deploy-reuse-vpc.sh
```

## 🔧 Development Environment Setup

### Required Tools

1. **Docker Desktop** (or Docker Engine + Compose)
   - Download: https://www.docker.com/products/docker-desktop
   - Verify: `docker --version` and `docker-compose --version`

2. **Node.js 18+**
   - Download: https://nodejs.org/
   - Verify: `node --version` (should be 18.x or higher)

3. **Python 3.11+**
   - Download: https://www.python.org/
   - Verify: `python --version` or `python3 --version`

4. **Git**
   - Download: https://git-scm.com/
   - Verify: `git --version`

5. **Code Editor** (Recommended: VS Code)
   - Download: https://code.visualstudio.com/

### Optional but Helpful

1. **Postman or Insomnia** - For API testing
2. **AWS CLI** - For AWS operations
3. **jq** - For JSON parsing in terminal: `brew install jq` (Mac) or `apt-get install jq` (Linux)

### VS Code Extensions (Recommended)

```json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-python.python",
    "ms-azuretools.vscode-docker",
    "bradlc.vscode-tailwindcss",
    "dsznajder.es7-react-js-snippets"
  ]
}
```

## 📖 Additional Resources to Share

### 1. Architecture Decision Records (ADRs)

Consider creating ADR documents for:
- Why microservices architecture?
- Why ECS over EKS or Lambda?
- Why FastAPI for order service?
- Service communication patterns
- Data storage decisions

**Template:**
```markdown
# ADR-001: Use Microservices Architecture

## Status
Accepted

## Context
[Describe the problem and constraints]

## Decision
[What was decided]

## Consequences
[Benefits and trade-offs]
```

### 2. API Documentation

**Recommendations:**
- Add Swagger/OpenAPI specs to each service
- Document all endpoints with examples
- Include error responses
- Add request/response schemas

**Example Structure:**
```
docs/
├── api/
│   ├── product-service-api.md
│   ├── order-service-api.md
│   └── api-gateway-routes.md
├── architecture/
│   ├── system-design.md
│   └── service-interactions.md
└── deployment/
    ├── local-setup.md
    └── aws-deployment.md
```

### 3. Development Guidelines

Create documentation for:

**Code Style:**
- JavaScript/TypeScript: ESLint + Prettier config
- Python: PEP 8 + Black formatter
- Git commit message conventions
- Branch naming conventions

**Example: `.prettierrc`**
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
```

### 4. Troubleshooting Guide

Document common issues and solutions:

```markdown
# Common Issues

## Port Already in Use
**Problem:** `Error: Port 3000 is already in use`
**Solution:**
```bash
# Find process using port
lsof -i :3000
# Kill the process
kill -9 <PID>
```

## Docker Build Fails
**Problem:** Docker build runs out of memory
**Solution:** Increase Docker memory in Docker Desktop settings

## Service Not Responding
**Problem:** Service health check fails
**Solution:**
1. Check service logs: `docker-compose logs service-name`
2. Verify service dependencies are running
3. Check network connectivity
```

### 5. Runbook for Operations

Create operational runbooks for:

**Deployment:**
- Pre-deployment checklist
- Deployment steps
- Rollback procedures
- Post-deployment verification

**Monitoring:**
- How to access CloudWatch logs
- Key metrics to monitor
- Alert thresholds
- On-call procedures

**Incident Response:**
- Severity definitions
- Escalation procedures
- Communication templates
- Post-mortem template

### 6. Example Workflows

**Adding a New Product:**
1. Add product to `product-service/data/products.json`
2. Restart product service
3. Verify via API: `curl http://localhost:3001/api/products/new-id`
4. Test order creation with new product

**Debugging an Order Issue:**
1. Check order service logs: `docker-compose logs order-service`
2. Verify product service is reachable
3. Test product fetch: `curl http://product-service:3001/api/products/prod-id`
4. Check order creation payload

**Deploying a Hotfix:**
1. Create hotfix branch: `git checkout -b hotfix/critical-bug`
2. Make fix and test locally
3. Run test suite: `./test-suite-enhanced.sh`
4. Build and push Docker images
5. Deploy via ECS: `./ecs-deployment/deploy-reuse-vpc.sh`
6. Monitor deployment and verify fix

## 🎓 Training Materials

### Internal Training Sessions (Recommended)

1. **Week 1: Architecture Overview** (2 hours)
   - System architecture walkthrough
   - Service responsibilities
   - Communication patterns
   - Q&A

2. **Week 2: Hands-on Development** (3 hours)
   - Setting up local environment
   - Making code changes
   - Running tests
   - Debugging techniques

3. **Week 3: AWS Deployment** (2 hours)
   - ECS concepts
   - Deployment process
   - Monitoring and logging
   - Troubleshooting

4. **Week 4: Best Practices** (1 hour)
   - Code reviews
   - Testing strategies
   - Security considerations
   - Performance optimization

### External Resources

**Microservices:**
- Martin Fowler's Microservices Guide
- "Building Microservices" by Sam Newman

**Docker:**
- Docker official documentation
- Docker Compose best practices

**AWS ECS:**
- AWS ECS documentation
- ECS task definition guide
- Application Load Balancer guide

**FastAPI:**
- FastAPI official documentation
- "FastAPI" tutorials on YouTube

**React:**
- React official documentation
- TypeScript + React guide

## 💬 Communication Channels

### Set Up These Channels:

1. **Slack/Teams Channels:**
   - `#spookymart-dev` - Development discussions
   - `#spookymart-alerts` - Automated alerts
   - `#spookymart-deployments` - Deployment notifications

2. **Documentation:**
   - Wiki/Confluence space
   - Shared Google Drive/OneDrive
   - GitHub Wiki

3. **Code Reviews:**
   - GitHub/GitLab Pull Requests
   - Review guidelines
   - Response time expectations

4. **Meetings:**
   - Daily standups (15 min)
   - Weekly planning (1 hour)
   - Bi-weekly retrospectives (1 hour)

## 🎯 First Week Goals

By the end of your first week, you should be able to:

- [ ] Start all services locally
- [ ] Make a simple code change
- [ ] Run the test suite successfully
- [ ] Understand the basic architecture
- [ ] Know where to find documentation
- [ ] Know who to ask for help

## 🚀 First Month Goals

By the end of your first month, you should be able to:

- [ ] Implement a new feature end-to-end
- [ ] Write and run tests for your changes
- [ ] Deploy changes to AWS ECS
- [ ] Debug issues independently
- [ ] Contribute to code reviews
- [ ] Understand the deployment process

## 📞 Getting Help

**Quick Questions:**
- Slack/Teams channels
- Ask your onboarding buddy

**Code Issues:**
- GitHub issues
- Team code reviews

**Urgent Problems:**
- On-call rotation
- Team lead contact

## 🎉 Welcome!

Remember: Everyone was new once. Don't hesitate to ask questions, and feel free to suggest improvements to this documentation!

---

**Questions about this guide?** Contact the platform team or create an issue in the repository.
