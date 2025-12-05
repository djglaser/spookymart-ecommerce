"""
SpookyMart Order Processing Service
Main FastAPI application for handling Halloween order processing
"""

import os
import signal
import asyncio
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import structlog
import uvicorn

from routes.orders import router as orders_router
from services.product_service import product_service

# Configure structured logging for Docker/CloudWatch
import sys
import logging

# Configure Python logging to go to stdout
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout,
    force=True
)

# Configure structured logging  
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Force stdout to be unbuffered for immediate Docker log output
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

# Test logging on startup
print("🚨 [STARTUP] Order Service Python logging test - this should appear in CloudWatch!")
sys.stdout.flush()
logger.info("Order Service structlog test - structured logging initialized")

# Environment configuration
PORT = int(os.getenv("PORT", 3002))
HOST = os.getenv("HOST", "0.0.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL", "http://localhost:3001")

# Global shutdown event
shutdown_event = asyncio.Event()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting SpookyMart Order Processing Service", 
               port=PORT, environment=ENVIRONMENT)
    
    # Configure Product Service URL
    product_service.base_url = PRODUCT_SERVICE_URL
    
    # Check Product Service health
    try:
        is_healthy = await product_service.health_check()
        if is_healthy:
            logger.info("Product Service is healthy", url=PRODUCT_SERVICE_URL)
        else:
            logger.warning("Product Service health check failed", url=PRODUCT_SERVICE_URL)
    except Exception as e:
        logger.error("Failed to check Product Service health", error=str(e))
    
    # Create data directory if it doesn't exist
    os.makedirs("data", exist_ok=True)
    
    yield
    
    # Shutdown
    logger.info("Shutting down SpookyMart Order Processing Service")


# Create FastAPI application
app = FastAPI(
    title="SpookyMart Order Processing Service",
    description="Halloween ecommerce order management API",
    version="1.0.0",
    docs_url="/docs" if ENVIRONMENT == "development" else None,
    redoc_url="/redoc" if ENVIRONMENT == "development" else None,
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all HTTP requests"""
    start_time = datetime.utcnow()
    
    # Special debug logging for POST orders (WITHOUT consuming body)
    if request.method == "POST" and "/api/orders" in str(request.url):
        print("=" * 120)
        print("🚨🚨🚨 [CRITICAL DEBUG] POST REQUEST HIT ORDER SERVICE MAIN APP! 🚨🚨🚨")
        print("=" * 120)
        print(f"🚨 [DEBUG] Request method: {request.method}")
        print(f"🚨 [DEBUG] Request URL: {request.url}")
        print(f"🚨 [DEBUG] Request path: {request.url.path}")
        print(f"🚨 [DEBUG] Client IP: {request.client.host if request.client else 'unknown'}")
        print(f"🚨 [DEBUG] Headers: {dict(request.headers)}")
        print(f"🚨 [DEBUG] Content-Type: {request.headers.get('content-type', 'unknown')}")
        print(f"🚨 [DEBUG] Content-Length: {request.headers.get('content-length', 'unknown')}")
        print("🚨 [DEBUG] This proves the POST request reached the Order Service!")
        print("🚨 [DEBUG] NOT reading body in middleware to allow route handler to process it")
        print("=" * 120)
    
    # Log request
    logger.info("HTTP request started",
               method=request.method,
               url=str(request.url),
               client_ip=request.client.host if request.client else None)
    
    # Process request
    response = await call_next(request)
    
    # Calculate duration
    duration = (datetime.utcnow() - start_time).total_seconds()
    
    # Special debug logging for POST orders response
    if request.method == "POST" and "/api/orders" in str(request.url):
        print("=" * 120)
        print("🚨🚨🚨 [CRITICAL DEBUG] POST ORDER RESPONSE FROM ORDER SERVICE! 🚨🚨🚨")
        print("=" * 120)
        print(f"🚨 [DEBUG] Response status: {response.status_code}")
        print(f"🚨 [DEBUG] Response headers: {dict(response.headers)}")
        print(f"🚨 [DEBUG] Duration: {duration:.3f} seconds")
        print("🚨 [DEBUG] About to return response to API Gateway!")
        print("=" * 120)
    
    # Log response
    logger.info("HTTP request completed",
               method=request.method,
               url=str(request.url),
               status_code=response.status_code,
               duration_seconds=duration)
    
    return response


# Exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle validation errors"""
    logger.warning("Validation error", 
                  url=str(request.url),
                  errors=exc.errors())
    
    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "error": "Validation Error",
            "message": "Request validation failed",
            "details": exc.errors()
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle unexpected errors"""
    logger.error("Unexpected error",
                url=str(request.url),
                error=str(exc),
                exc_info=True)
    
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": "Internal Server Error",
            "message": "An unexpected error occurred" if ENVIRONMENT == "production" else str(exc)
        }
    )


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for ECS monitoring"""
    try:
        # Check Product Service health
        product_service_healthy = await product_service.health_check()
        
        health_status = {
            "status": "healthy",
            "service": "spookymart-order-service",
            "version": "1.0.0",
            "timestamp": datetime.utcnow().isoformat(),
            "environment": ENVIRONMENT,
            "dependencies": {
                "product_service": {
                    "url": PRODUCT_SERVICE_URL,
                    "healthy": product_service_healthy
                }
            }
        }
        
        # If any dependency is unhealthy, mark service as degraded
        if not product_service_healthy:
            health_status["status"] = "degraded"
            health_status["message"] = "Some dependencies are unhealthy"
        
        status_code = 200 if health_status["status"] == "healthy" else 503
        
        return JSONResponse(
            status_code=status_code,
            content=health_status
        )
        
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "spookymart-order-service",
                "version": "1.0.0",
                "timestamp": datetime.utcnow().isoformat(),
                "error": str(e)
            }
        )


# API information endpoint
@app.get("/")
async def api_info():
    """API information and documentation"""
    return {
        "service": "SpookyMart Order Processing Service",
        "version": "1.0.0",
        "description": "Halloween ecommerce order management API",
        "environment": ENVIRONMENT,
        "endpoints": {
            "health": "GET /health",
            "orders": {
                "list": "GET /api/orders",
                "create": "POST /api/orders",
                "get": "GET /api/orders/{order_id}",
                "update": "PUT /api/orders/{order_id}",
                "cancel": "POST /api/orders/{order_id}/cancel",
                "status": "GET /api/orders/{order_id}/status"
            }
        },
        "documentation": {
            "swagger": "/docs" if ENVIRONMENT == "development" else "disabled",
            "redoc": "/redoc" if ENVIRONMENT == "development" else "disabled"
        },
        "dependencies": {
            "product_service": PRODUCT_SERVICE_URL
        }
    }


# Include routers
app.include_router(orders_router, prefix="/api/orders", tags=["orders"])


# Graceful shutdown handler
def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info("Received shutdown signal", signal=signum)
    shutdown_event.set()


# Register signal handlers
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


async def main():
    """Main application entry point"""
    config = uvicorn.Config(
        app,
        host=HOST,
        port=PORT,
        log_config=None,  # Use our structured logging
        access_log=False,  # We handle request logging in middleware
    )
    
    server = uvicorn.Server(config)
    
    # Start server in background
    server_task = asyncio.create_task(server.serve())
    
    # Log startup message
    if ENVIRONMENT == "development":
        logger.info("\n🎃 SpookyMart Order Processing Service is running!")
        logger.info(f"📍 Server: http://{HOST}:{PORT}")
        logger.info(f"🏥 Health: http://{HOST}:{PORT}/health")
        logger.info(f"📦 Orders: http://{HOST}:{PORT}/api/orders")
        logger.info(f"📚 API Docs: http://{HOST}:{PORT}/docs")
        logger.info(f"🔗 Product Service: {PRODUCT_SERVICE_URL}")
        logger.info("\n👻 Ready to process some spooky orders!\n")
    
    # Wait for shutdown signal
    await shutdown_event.wait()
    
    # Graceful shutdown
    logger.info("Starting graceful shutdown...")
    server.should_exit = True
    
    # Wait for server to finish
    try:
        await asyncio.wait_for(server_task, timeout=30.0)
    except asyncio.TimeoutError:
        logger.warning("Server shutdown timeout, forcing exit")
    
    logger.info("Shutdown complete")


if __name__ == "__main__":
    # Simple startup for development
    if ENVIRONMENT == "development":
        print("\n🎃 SpookyMart Order Processing Service is starting...")
        print(f"📍 Server: http://{HOST}:{PORT}")
        print(f"🏥 Health: http://{HOST}:{PORT}/health")
        print(f"📦 Orders: http://{HOST}:{PORT}/api/orders")
        print(f"📚 API Docs: http://{HOST}:{PORT}/docs")
        print(f"🔗 Product Service: {PRODUCT_SERVICE_URL}")
        print("\n👻 Ready to process some spooky orders!\n")
    
    # Run the server directly with uvicorn
    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        log_config=None,
        access_log=False
    )
