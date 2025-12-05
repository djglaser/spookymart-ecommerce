# SpookyMart Product Service 🎃

A Node.js microservice for managing Halloween products in the SpookyMart ecommerce platform. This service provides a RESTful API for product catalog management with full CRUD operations.

## Features

- **Product Management**: Create, read, update, and delete Halloween products
- **Category Support**: Costumes, Decorations, Candy, Masks, Props, Makeup, Accessories, Lights
- **Advanced Filtering**: Filter by category, price range, stock availability
- **Pagination**: Efficient data retrieval with limit/offset pagination
- **Data Validation**: Comprehensive input validation using Joi
- **Security**: Helmet middleware for security headers
- **CORS Support**: Cross-origin resource sharing for frontend integration
- **Health Checks**: Built-in health monitoring for ECS deployment
- **Structured Logging**: JSON logging for CloudWatch integration
- **Graceful Shutdown**: Proper container lifecycle management

## API Endpoints

### Product Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/products` | List all products with optional filtering |
| GET | `/api/products/:id` | Get a specific product by ID |
| POST | `/api/products` | Create a new product |
| PUT | `/api/products/:id` | Update an existing product |
| DELETE | `/api/products/:id` | Soft delete a product |
| GET | `/api/products/categories/list` | Get available categories |

### System Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information and documentation |
| GET | `/health` | Health check for monitoring |

## Query Parameters

### GET /api/products

- `category` - Filter by product category
- `minPrice` - Minimum price filter
- `maxPrice` - Maximum price filter  
- `inStock` - Filter by stock availability (true/false)
- `limit` - Number of products to return (default: 50, max: 100)
- `offset` - Number of products to skip (default: 0)

**Example:**
```
GET /api/products?category=Costumes&minPrice=20&maxPrice=100&inStock=true&limit=10
```

## Product Schema

```json
{
  "id": "string (UUID)",
  "name": "string (3-100 chars)",
  "description": "string (10-500 chars)",
  "price": "number (positive, 2 decimal places)",
  "category": "string (enum: Costumes, Decorations, Candy, etc.)",
  "stock": "number (integer, >= 0)",
  "imageUrl": "string (valid URL, optional)",
  "tags": "array of strings (optional)",
  "isActive": "boolean (default: true)",
  "createdAt": "ISO date string",
  "updatedAt": "ISO date string"
}
```

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Docker (for containerization)

### Local Development

1. **Install Dependencies**
   ```bash
   npm install
   ```

2. **Start Development Server**
   ```bash
   npm run dev
   ```
   
   The service will start on `http://localhost:3001`

3. **Start Production Server**
   ```bash
   npm start
   ```

### Docker Development

1. **Build Docker Image**
   ```bash
   docker build -t spookymart-product-service .
   ```

2. **Run Container**
   ```bash
   docker run -p 3001:3001 spookymart-product-service
   ```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3001` |
| `NODE_ENV` | Environment mode | `development` |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | `*` |

## Sample API Usage

### Create a Product

```bash
curl -X POST http://localhost:3001/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ghost Costume",
    "description": "Classic white ghost costume with flowing fabric",
    "price": 29.99,
    "category": "Costumes",
    "stock": 15,
    "tags": ["ghost", "classic", "white"]
  }'
```

### Get All Products

```bash
curl http://localhost:3001/api/products
```

### Filter Products by Category

```bash
curl "http://localhost:3001/api/products?category=Costumes&limit=5"
```

### Update a Product

```bash
curl -X PUT http://localhost:3001/api/products/prod-001 \
  -H "Content-Type: application/json" \
  -d '{
    "price": 39.99,
    "stock": 20
  }'
```

## Response Format

All API responses follow this structure:

### Success Response
```json
{
  "success": true,
  "data": {
    "product": { /* product object */ },
    "pagination": { /* pagination info for lists */ }
  },
  "message": "Optional success message"
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error Type",
  "message": "Human readable error message",
  "details": [ /* validation details if applicable */ ]
}
```

## ECS Deployment

This service is designed for Amazon ECS deployment with:

- **Health Checks**: `/health` endpoint for ECS health monitoring
- **Graceful Shutdown**: Proper SIGTERM handling
- **Structured Logging**: JSON logs for CloudWatch
- **Security**: Non-root user in container
- **Multi-stage Build**: Optimized Docker image

### ECS Task Definition Example

```json
{
  "family": "spookymart-product-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "product-service",
      "image": "your-ecr-repo/spookymart-product-service:latest",
      "portMappings": [
        {
          "containerPort": 3001,
          "protocol": "tcp"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3001/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/spookymart-product-service",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

## Architecture Notes

- **File-based Storage**: Currently uses JSON file for simplicity. Can be upgraded to database (MongoDB, PostgreSQL) later
- **Validation**: Joi schema validation for all inputs
- **Error Handling**: Comprehensive error handling with proper HTTP status codes
- **Security**: Helmet middleware, input validation, non-root container user
- **Monitoring**: Health checks, structured logging, graceful shutdown

## Next Steps

1. **Database Integration**: Replace file storage with MongoDB or PostgreSQL
2. **Authentication**: Add JWT-based authentication
3. **Rate Limiting**: Implement API rate limiting
4. **Caching**: Add Redis caching for frequently accessed products
5. **Search**: Implement full-text search capabilities
6. **Image Upload**: Add product image upload functionality

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details
