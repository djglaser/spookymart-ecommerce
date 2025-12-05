# SpookyMart Order Processing Service 🎃👻

A Python FastAPI microservice for managing Halloween orders in the SpookyMart ecommerce platform. This service handles order creation, validation, status tracking, and integrates with the Product Service for inventory management.

## Features

- **Order Management**: Complete order lifecycle from creation to delivery
- **Product Integration**: Real-time validation with Product Service
- **Inventory Checking**: Validates product availability and pricing
- **Order Status Tracking**: Multiple status states with timestamps
- **Payment Processing**: Basic payment workflow (placeholder for real integration)
- **Data Validation**: Comprehensive input validation using Pydantic
- **Async Operations**: High-performance async/await architecture
- **Health Monitoring**: Built-in health checks for ECS deployment
- **Structured Logging**: JSON logging for CloudWatch integration
- **Graceful Shutdown**: Proper container lifecycle management

## Order Status Flow

```
PENDING → CONFIRMED → PROCESSING → SHIPPED → DELIVERED
    ↓
CANCELLED (can cancel before SHIPPED)
    ↓
REFUNDED (if payment was captured)
```

## API Endpoints

### Order Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/orders` | Create a new order |
| GET | `/api/orders` | List orders with filtering |
| GET | `/api/orders/{order_id}` | Get specific order |
| PUT | `/api/orders/{order_id}` | Update order details |
| POST | `/api/orders/{order_id}/cancel` | Cancel an order |
| GET | `/api/orders/{order_id}/status` | Get order status |

### System Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information |
| GET | `/health` | Health check with dependencies |
| GET | `/docs` | Interactive API documentation (dev only) |

## Order Schema

```json
{
  "id": "uuid",
  "order_number": "SPK-2024-001001",
  "customer": {
    "email": "customer@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "phone": "+15551234567"
  },
  "items": [
    {
      "product_id": "prod-001",
      "product_name": "Vampire Costume Deluxe",
      "quantity": 1,
      "unit_price": 49.99,
      "total_price": 49.99
    }
  ],
  "shipping_address": {
    "street": "123 Spooky Lane",
    "city": "Halloween City",
    "state": "CA",
    "zip_code": "90210",
    "country": "US"
  },
  "payment": {
    "payment_method": "credit_card",
    "payment_status": "pending",
    "payment_amount": 54.99
  },
  "subtotal": 49.99,
  "tax_amount": 4.00,
  "shipping_cost": 0.00,
  "total_amount": 53.99,
  "status": "pending",
  "created_at": "2024-11-01T17:30:00Z",
  "updated_at": "2024-11-01T17:30:00Z"
}
```

## Getting Started

### Prerequisites

- Python 3.11+
- pip or poetry
- Docker (for containerization)
- Running Product Service (http://localhost:3001)

### Local Development

1. **Install Dependencies**
   ```bash
   cd order-service
   pip install -r requirements.txt
   ```

2. **Set Environment Variables**
   ```bash
   export PRODUCT_SERVICE_URL=http://localhost:3001
   export PORT=3002
   export ENVIRONMENT=development
   ```

3. **Start the Service**
   ```bash
   python main.py
   ```
   
   The service will start on `http://localhost:3002`

4. **View API Documentation**
   - Swagger UI: http://localhost:3002/docs
   - ReDoc: http://localhost:3002/redoc

### Docker Development

1. **Build Docker Image**
   ```bash
   docker build -t spookymart-order-service .
   ```

2. **Run Container**
   ```bash
   docker run -p 3002:3002 \
     -e PRODUCT_SERVICE_URL=http://host.docker.internal:3001 \
     spookymart-order-service
   ```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3002` |
| `HOST` | Server host | `0.0.0.0` |
| `ENVIRONMENT` | Environment mode | `development` |
| `PRODUCT_SERVICE_URL` | Product Service URL | `http://localhost:3001` |
| `ALLOWED_ORIGINS` | CORS allowed origins | `*` |

## Sample API Usage

### Create an Order

```bash
curl -X POST http://localhost:3002/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer": {
      "email": "customer@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "phone": "+15551234567"
    },
    "items": [
      {
        "product_id": "prod-001",
        "product_name": "Vampire Costume Deluxe",
        "quantity": 1,
        "unit_price": 49.99,
        "total_price": 49.99
      }
    ],
    "shipping_address": {
      "street": "123 Spooky Lane",
      "city": "Halloween City",
      "state": "CA",
      "zip_code": "90210"
    },
    "payment_method": "credit_card"
  }'
```

### List Orders

```bash
# Get all orders
curl http://localhost:3002/api/orders

# Filter by status
curl "http://localhost:3002/api/orders?status=pending"

# Filter by customer email
curl "http://localhost:3002/api/orders?customer_email=customer@example.com"

# Pagination
curl "http://localhost:3002/api/orders?limit=10&offset=0"
```

### Update Order Status

```bash
curl -X PUT http://localhost:3002/api/orders/{order_id} \
  -H "Content-Type: application/json" \
  -d '{
    "status": "confirmed",
    "notes": "Order confirmed and ready for processing"
  }'
```

### Add Tracking Number

```bash
curl -X PUT http://localhost:3002/api/orders/{order_id} \
  -H "Content-Type: application/json" \
  -d '{
    "tracking_number": "1Z999AA1234567890"
  }'
```

### Cancel Order

```bash
curl -X POST http://localhost:3002/api/orders/{order_id}/cancel
```

## Order Processing Workflow

### 1. Order Creation
- Validates customer information
- Checks product availability with Product Service
- Verifies pricing consistency
- Calculates taxes and shipping
- Reserves inventory (placeholder)
- Creates order with PENDING status

### 2. Order Validation
- **Product Validation**: Ensures all products exist and are active
- **Inventory Check**: Verifies sufficient stock for each item
- **Price Validation**: Confirms prices match Product Service
- **Address Validation**: Validates shipping address format
- **Payment Validation**: Basic payment method validation

### 3. Tax and Shipping Calculation
- **Tax**: 8% of subtotal (configurable)
- **Shipping**: Free over $50, otherwise $5.99
- **Total**: Subtotal + Tax + Shipping

### 4. Status Management
- **PENDING**: Order created, awaiting confirmation
- **CONFIRMED**: Order validated and confirmed
- **PROCESSING**: Order being prepared for shipment
- **SHIPPED**: Order shipped with tracking number
- **DELIVERED**: Order delivered to customer
- **CANCELLED**: Order cancelled (before shipping)
- **REFUNDED**: Payment refunded

## Integration with Product Service

The Order Service integrates with the Product Service for:

- **Product Validation**: Verify products exist and are active
- **Inventory Checking**: Ensure sufficient stock
- **Price Verification**: Confirm current pricing
- **Batch Operations**: Efficient multi-product validation
- **Health Monitoring**: Check Product Service availability

### Error Handling

- **Product Not Found**: Returns 400 with specific product details
- **Insufficient Stock**: Returns 409 with availability info
- **Price Mismatch**: Returns 400 with expected vs actual prices
- **Service Unavailable**: Returns 503 when Product Service is down

## ECS Deployment

This service is designed for Amazon ECS deployment with:

- **Health Checks**: `/health` endpoint with dependency monitoring
- **Graceful Shutdown**: Proper SIGTERM handling
- **Structured Logging**: JSON logs for CloudWatch
- **Security**: Non-root user in container
- **Multi-stage Build**: Optimized Docker image
- **Dependency Health**: Monitors Product Service health

### ECS Task Definition Example

```json
{
  "family": "spookymart-order-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "order-service",
      "image": "your-ecr-repo/spookymart-order-service:latest",
      "portMappings": [
        {
          "containerPort": 3002,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "PRODUCT_SERVICE_URL",
          "value": "http://product-service.internal:3001"
        },
        {
          "name": "ENVIRONMENT",
          "value": "production"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "python -c \"import httpx; httpx.get('http://localhost:3002/health', timeout=2.0)\""],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/spookymart-order-service",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

## Response Format

All API responses follow this structure:

### Success Response
```json
{
  "success": true,
  "message": "Order created successfully",
  "order": { /* order object */ }
}
```

### Error Response
```json
{
  "success": false,
  "error": "Validation Error",
  "message": "One or more items in the order are invalid",
  "details": ["Product prod-999 not found"]
}
```

## Architecture Notes

- **File-based Storage**: Currently uses JSON file for simplicity. Can be upgraded to database (PostgreSQL, MongoDB) later
- **Async Architecture**: Built with FastAPI and async/await for high performance
- **Pydantic Validation**: Comprehensive data validation and serialization
- **Service Integration**: HTTP-based communication with Product Service
- **Error Handling**: Comprehensive error handling with proper HTTP status codes
- **Security**: Input validation, non-root container user, CORS configuration

## Development

### Code Structure
```
order-service/
├── main.py                 # FastAPI application
├── models/
│   └── order.py           # Pydantic models
├── routes/
│   └── orders.py          # API routes
├── services/
│   └── product_service.py # Product Service integration
├── data/
│   └── orders.json        # Order storage (demo)
├── requirements.txt       # Python dependencies
├── Dockerfile            # Container configuration
└── README.md            # This file
```

### Running Tests
```bash
# Install test dependencies
pip install pytest pytest-asyncio

# Run tests
pytest
```

### Code Formatting
```bash
# Format code
black .

# Lint code
flake8 .
```

## Next Steps

1. **Database Integration**: Replace file storage with PostgreSQL or MongoDB
2. **Payment Integration**: Add real payment processing (Stripe, PayPal)
3. **Inventory Management**: Implement real inventory reservation and release
4. **Notification System**: Add email/SMS notifications for order updates
5. **Order Analytics**: Add order metrics and reporting
6. **Fraud Detection**: Implement order validation and fraud checks
7. **Shipping Integration**: Add real shipping carrier integration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details
