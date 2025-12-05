# SpookyMart API Gateway

The API Gateway service acts as the central entry point for the SpookyMart ecommerce application, routing requests to the appropriate microservices and providing cross-cutting concerns like authentication, rate limiting, and logging.

## Features

- **Service Routing**: Routes requests to Product Service and Order Service
- **Rate Limiting**: Protects backend services from abuse
- **Security**: Implements CORS, Helmet security headers
- **Logging**: Comprehensive request/response logging with Winston
- **Health Checks**: Monitors downstream service health
- **Compression**: Reduces response payload sizes
- **Error Handling**: Graceful error responses and service unavailability handling

## Architecture

```
Client Request → API Gateway → Backend Services
                    ↓
            [Product Service] [Order Service]
                (Port 3001)    (Port 3002)
```

## API Routes

### Health Check
- **GET** `/health` - Returns gateway and downstream service health status

### Product Service Routes
- **GET** `/api/products` - Get all products
- **GET** `/api/products/:id` - Get product by ID
- **POST** `/api/products` - Create new product
- **PUT** `/api/products/:id` - Update product
- **DELETE** `/api/products/:id` - Delete product

### Order Service Routes
- **GET** `/api/orders` - Get all orders
- **GET** `/api/orders/:id` - Get order by ID
- **POST** `/api/orders` - Create new order
- **PUT** `/api/orders/:id` - Update order
- **DELETE** `/api/orders/:id` - Delete order

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Port for the API Gateway |
| `PRODUCT_SERVICE_URL` | http://localhost:3001 | Product Service URL |
| `ORDER_SERVICE_URL` | http://localhost:3002 | Order Service URL |
| `NODE_ENV` | development | Environment (development/production) |
| `LOG_LEVEL` | info | Logging level (error/warn/info/debug) |

### Rate Limiting

- **Window**: 15 minutes
- **Max Requests**: 100 per IP
- **Headers**: Includes rate limit info in response headers

## Development

### Prerequisites

- Node.js 18+
- npm or yarn
- Running Product Service (port 3001)
- Running Order Service (port 3002)

### Installation

```bash
npm install
```

### Running Locally

```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

### Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage
```

## Docker

### Building the Image

```bash
docker build -t spookymart-api-gateway .
```

### Running with Docker

```bash
docker run -p 3000:3000 \
  -e PRODUCT_SERVICE_URL=http://product-service:3001 \
  -e ORDER_SERVICE_URL=http://order-service:3002 \
  spookymart-api-gateway
```

## ECS Deployment

### Task Definition Example

```json
{
  "family": "spookymart-api-gateway",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "api-gateway",
      "image": "your-registry/spookymart-api-gateway:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PRODUCT_SERVICE_URL",
          "value": "http://product-service.local:3001"
        },
        {
          "name": "ORDER_SERVICE_URL",
          "value": "http://order-service.local:3002"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/spookymart-api-gateway",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:3000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

## Monitoring

### Health Check Response

```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "uptime": 3600,
  "services": {
    "product-service": {
      "status": "healthy",
      "url": "http://localhost:3001",
      "responseTime": 45
    },
    "order-service": {
      "status": "healthy", 
      "url": "http://localhost:3002",
      "responseTime": 32
    }
  }
}
```

### Logs

The API Gateway uses structured logging with Winston. Logs include:

- Request/response details
- Service proxy information
- Error tracking
- Performance metrics

### Metrics

Key metrics to monitor:

- Request rate and response times
- Error rates by service
- Downstream service health
- Rate limit violations

## Security

- **CORS**: Configured for cross-origin requests
- **Helmet**: Security headers (CSP, HSTS, etc.)
- **Rate Limiting**: Prevents abuse
- **Input Validation**: Proxied to downstream services
- **Error Sanitization**: Prevents information leakage

## Troubleshooting

### Common Issues

1. **Service Unavailable (503)**
   - Check if downstream services are running
   - Verify service URLs in environment variables
   - Check network connectivity

2. **Rate Limit Exceeded (429)**
   - Reduce request frequency
   - Check rate limit configuration
   - Consider implementing authentication for higher limits

3. **CORS Errors**
   - Verify CORS configuration
   - Check request origin
   - Ensure preflight requests are handled

### Debug Mode

Enable debug logging:

```bash
LOG_LEVEL=debug npm start
```

## Contributing

1. Follow the existing code style
2. Add tests for new features
3. Update documentation
4. Ensure all services pass health checks
