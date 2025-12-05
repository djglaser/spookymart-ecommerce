/**
 * SpookyMart API Gateway
 * Central entry point for all SpookyMart microservices
 * Handles routing, authentication, rate limiting, and monitoring
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { createProxyMiddleware } = require('http-proxy-middleware');
const axios = require('axios');
const winston = require('winston');
require('dotenv').config();

// Configuration
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const NODE_ENV = process.env.NODE_ENV || 'development';

// Service URLs
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://localhost:3001';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://localhost:3002';

// Initialize Express app
const app = express();

// Trust proxy headers from ALB (fixes X-Forwarded-For rate limiting errors)
app.set('trust proxy', true);

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'spookymart-api-gateway' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
  ],
});

// Add console transport for development
if (NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
}));

// Compression middleware
app.use(compression());

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too Many Requests',
    message: 'Rate limit exceeded. Please try again later.',
    retryAfter: '15 minutes'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api/', limiter);

// Health check middleware for services
const healthCheck = async (serviceUrl, serviceName) => {
  try {
    const response = await axios.get(`${serviceUrl}/health`, { timeout: 5000 });
    return {
      name: serviceName,
      status: 'healthy',
      url: serviceUrl,
      responseTime: response.headers['x-response-time'] || 'N/A',
      lastChecked: new Date().toISOString()
    };
  } catch (error) {
    return {
      name: serviceName,
      status: 'unhealthy',
      url: serviceUrl,
      error: error.message,
      lastChecked: new Date().toISOString()
    };
  }
};

// API Gateway health endpoint
app.get('/health', async (req, res) => {
  try {
    const [productHealth, orderHealth] = await Promise.all([
      healthCheck(PRODUCT_SERVICE_URL, 'Product Service'),
      healthCheck(ORDER_SERVICE_URL, 'Order Service')
    ]);

    const overallHealth = productHealth.status === 'healthy' && orderHealth.status === 'healthy' 
      ? 'healthy' : 'degraded';

    const healthStatus = {
      status: overallHealth,
      service: 'spookymart-api-gateway',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      environment: NODE_ENV,
      uptime: process.uptime(),
      services: {
        product: productHealth,
        order: orderHealth
      }
    };

    const statusCode = overallHealth === 'healthy' ? 200 : 503;
    res.status(statusCode).json(healthStatus);
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      service: 'spookymart-api-gateway',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Service connectivity test endpoint
app.get('/api/debug/connectivity', async (req, res) => {
  console.log('🔍 [DEBUG] CONNECTIVITY TEST REQUESTED');
  
  try {
    // Test Order Service connectivity
    console.log(`🔍 [DEBUG] Testing connection to: ${ORDER_SERVICE_URL}`);
    const orderResponse = await axios.get(`${ORDER_SERVICE_URL}/health`, { 
      timeout: 10000,
      headers: {
        'User-Agent': 'API-Gateway-Debug-Test'
      }
    });
    
    console.log(`🔍 [DEBUG] Order Service response: ${orderResponse.status}`);
    
    res.json({
      debug: 'connectivity-test',
      timestamp: new Date().toISOString(),
      tests: {
        order_service: {
          url: ORDER_SERVICE_URL,
          status: 'success',
          response_code: orderResponse.status,
          response_data: orderResponse.data
        }
      }
    });
    
  } catch (error) {
    console.log(`🔍 [DEBUG] Order Service connection FAILED: ${error.message}`);
    console.log(`🔍 [DEBUG] Error details:`, error.code, error.errno);
    
    res.status(503).json({
      debug: 'connectivity-test',
      timestamp: new Date().toISOString(),
      tests: {
        order_service: {
          url: ORDER_SERVICE_URL,
          status: 'failed',
          error: error.message,
          error_code: error.code,
          error_errno: error.errno
        }
      }
    });
  }
});

// API information endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'SpookyMart API Gateway',
    version: '1.0.0',
    description: 'Central API Gateway for SpookyMart Halloween Ecommerce Platform',
    environment: NODE_ENV,
    endpoints: {
      health: 'GET /health',
      products: {
        base: '/api/products',
        list: 'GET /api/products',
        get: 'GET /api/products/:id',
        create: 'POST /api/products',
        update: 'PUT /api/products/:id',
        delete: 'DELETE /api/products/:id',
        categories: 'GET /api/products/categories/list'
      },
      orders: {
        base: '/api/orders',
        list: 'GET /api/orders',
        get: 'GET /api/orders/:id',
        create: 'POST /api/orders',
        update: 'PUT /api/orders/:id',
        cancel: 'POST /api/orders/:id/cancel',
        status: 'GET /api/orders/:id/status'
      }
    },
    services: {
      product: PRODUCT_SERVICE_URL,
      order: ORDER_SERVICE_URL
    },
    documentation: {
      product_service: `${PRODUCT_SERVICE_URL}/`,
      order_service: `${ORDER_SERVICE_URL}/docs`
    }
  });
});

// Proxy configuration for Product Service
const productProxy = createProxyMiddleware({
  target: PRODUCT_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: {
    '^/api/products': '/api/products'
  },
  onError: (err, req, res) => {
    logger.error('Product Service proxy error:', err);
    res.status(503).json({
      error: 'Service Unavailable',
      message: 'Product Service is currently unavailable',
      service: 'product-service'
    });
  },
  onProxyReq: (proxyReq, req, res) => {
    logger.info(`Proxying to Product Service: ${req.method} ${req.path}`);
  },
  onProxyRes: (proxyRes, req, res) => {
    logger.info(`Product Service response: ${proxyRes.statusCode} for ${req.method} ${req.path}`);
  }
});

// Proxy configuration for Order Service
const orderProxy = createProxyMiddleware({
  target: ORDER_SERVICE_URL,
  changeOrigin: true,
  pathRewrite: {
    '^/api/orders': '/api/orders/'
  },
  onError: (err, req, res) => {
    logger.error('Order Service proxy error:', err);
    res.status(503).json({
      error: 'Service Unavailable',
      message: 'Order Service is currently unavailable',
      service: 'order-service'
    });
  },
  onProxyReq: (proxyReq, req, res) => {
    logger.info(`Proxying to Order Service: ${req.method} ${req.path}`);
  },
  onProxyRes: (proxyRes, req, res) => {
    logger.info(`Order Service response: ${proxyRes.statusCode} for ${req.method} ${req.path}`);
  }
});

// Add debug middleware for Order Service requests
app.use('/api/orders', (req, res, next) => {
  console.log('='.repeat(80));
  console.log('🚨 [DEBUG] API GATEWAY REQUEST RECEIVED! 🚨');
  console.log(`🚨 [DEBUG] Method: ${req.method} | Path: ${req.path} | URL: ${req.originalUrl}`);
  console.log('🚨 [DEBUG] API Gateway is ALIVE and routing order requests!');
  console.log(`🚨 [DEBUG] Target: ${ORDER_SERVICE_URL}`);
  if (req.method === 'POST') {
    console.log('🚨 [DEBUG] POST REQUEST - This is the failing request!');
    console.log(`🚨 [DEBUG] Body: ${JSON.stringify(req.body)}`);
  }
  console.log('='.repeat(80));
  next();
});

// Route definitions
app.use('/api/products', productProxy);
app.use('/api/orders', orderProxy);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.originalUrl} not found`,
    availableEndpoints: [
      'GET /',
      'GET /health',
      'GET /api/products',
      'POST /api/products',
      'GET /api/orders',
      'POST /api/orders'
    ]
  });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  
  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: NODE_ENV === 'production' ? 'Something went wrong' : err.message,
    ...(NODE_ENV !== 'production' && { stack: err.stack })
  });
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`);
  
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
  
  // Force close after 30 seconds
  setTimeout(() => {
    logger.error('Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 30000);
};

// Start server
const server = app.listen(PORT, HOST, () => {
  logger.info(`🎃 SpookyMart API Gateway is running!`);
  logger.info(`📍 Server: http://${HOST}:${PORT}`);
  logger.info(`🏥 Health: http://${HOST}:${PORT}/health`);
  logger.info(`🔗 Product Service: ${PRODUCT_SERVICE_URL}`);
  logger.info(`📦 Order Service: ${ORDER_SERVICE_URL}`);
  logger.info(`🌍 Environment: ${NODE_ENV}`);
  logger.info(`\n👻 Ready to route some spooky requests!\n`);
});

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

module.exports = app;
