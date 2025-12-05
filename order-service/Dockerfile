# SpookyMart Order Processing Service Dockerfile
# Multi-stage build for optimized production image

# Stage 1: Build stage
FROM python:3.11-slim AS builder

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Production stage
FROM python:3.11-slim AS production

# Create app directory
WORKDIR /app

# Create non-root user for security
RUN groupadd -r spookymart && useradd -r -g spookymart spookymart

# Copy Python dependencies from builder stage
COPY --from=builder /root/.local /home/spookymart/.local

# Make sure scripts in .local are usable
ENV PATH=/home/spookymart/.local/bin:$PATH

# Copy application code
COPY --chown=spookymart:spookymart . .

# Create data directory with proper permissions
RUN mkdir -p data && chown -R spookymart:spookymart data

# Create empty orders file
RUN echo "[]" > data/orders.json && chown spookymart:spookymart data/orders.json

# Expose port
EXPOSE 3002

# Add health check for ECS
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import httpx; import sys; \
    try: \
      response = httpx.get('http://localhost:3002/health', timeout=2.0); \
      sys.exit(0 if response.status_code == 200 else 1) \
    except: \
      sys.exit(1)"

# Switch to non-root user
USER spookymart

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV ENVIRONMENT=production
ENV PORT=3002
ENV HOST=0.0.0.0

# Start the application
CMD ["python", "main.py"]
