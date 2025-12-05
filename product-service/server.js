const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const productRoutes = require('./routes/products');
const { errorHandler } = require('./middleware/validation');

/**
 * SpookyMart Product Service
 * Main server file that configures Express application
 */

const app = express();

// Environment configuration
const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'development';

/**
 * Middleware Configuration
 */

// Security middleware - adds various HTTP headers for security
app.use(helmet());

// CORS middleware - allows cross-origin requests
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true
}));

// Request parsing middleware
app.use(express.json({ limit: '10mb' })); // Parse JSON bodies
app.use(express.urlencoded({ extended: true, limit: '10mb' })); // Parse URL-encoded bodies

// Logging middleware - different formats for development vs production
if (NODE_ENV === 'development') {
  // Colored output for development
  app.use(morgan('dev'));
} else {
  // JSON format for production (better for CloudWatch parsing)
  app.use(morgan('combined', {
    stream: {
      write: (message) => {
        // Log as JSON for structured logging in CloudWatch
        console.log(JSON.stringify({
          timestamp: new Date().toISOString(),
          level: 'info',
          type: 'http_request',
          message: message.trim()
        }));
      }
    }
  }));
}

/**
 * Health Check Endpoint
 * Used by ECS for health monitoring
 */
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'spookymart-product-service',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: NODE_ENV
  });
});

/**
 * API Information Endpoint
 */
app.get('/', (req, res) => {
  res.json({
    service: 'SpookyMart Product Service',
    version: '1.0.0',
    description: 'Halloween ecommerce product management API',
    endpoints: {
      health: 'GET /health',
      products: {
        list: 'GET /api/products',
        get: 'GET /api/products/:id',
        create: 'POST /api/products',
        update: 'PUT /api/products/:id',
        delete: 'DELETE /api/products/:id',
        categories: 'GET /api/products/categories/list'
      }
    },
    documentation: 'https://github.com/spookymart/product-service/README.md'
  });
});

/**
 * API Routes
 */
app.use('/api/products', productRoutes);

/**
 * 404 Handler - for routes that don't exist
 */
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not Found',
    message: `Route ${req.method} ${req.originalUrl} not found`,
    availableEndpoints: [
      'GET /',
      'GET /health',
      'GET /api/products',
      'GET /api/products/:id',
      'POST /api/products',
      'PUT /api/products/:id',
      'DELETE /api/products/:id',
      'GET /api/products/categories/list'
    ]
  });
});

/**
 * Global Error Handler
 */
app.use(errorHandler);

/**
 * Graceful Shutdown Handler
 * Important for ECS deployments
 */
let server;

const gracefulShutdown = (signal) => {
  console.log(`Received ${signal}. Starting graceful shutdown...`);
  
  if (server) {
    server.close((err) => {
      if (err) {
        console.error('Error during server shutdown:', err);
        process.exit(1);
      }
      
      console.log('Server closed successfully');
      process.exit(0);
    });
    
    // Force shutdown after 30 seconds
    setTimeout(() => {
      console.error('Forced shutdown after timeout');
      process.exit(1);
    }, 30000);
  } else {
    process.exit(0);
  }
};

// Listen for shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  gracefulShutdown('unhandledRejection');
});

/**
 * Start Server
 */
server = app.listen(PORT, '0.0.0.0', () => {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'info',
    message: `SpookyMart Product Service started`,
    port: PORT,
    environment: NODE_ENV,
    pid: process.pid
  }));
  
  // Log available endpoints in development
  if (NODE_ENV === 'development') {
    console.log('\n🎃 SpookyMart Product Service is running!');
    console.log(`📍 Server: http://localhost:${PORT}`);
    console.log(`🏥 Health: http://localhost:${PORT}/health`);
    console.log(`📦 Products: http://localhost:${PORT}/api/products`);
    console.log(`📚 API Info: http://localhost:${PORT}/`);
    console.log('\n👻 Ready to serve some spooky products!\n');
  }
});

module.exports = app;
