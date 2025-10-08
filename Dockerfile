# Multi-stage Dockerfile for TFVisualizer (Python Flask Application)
# Optimized for production deployment with minimal image size

# Stage 1: Production Runtime
FROM alpine:3.22.1 AS production

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    postgresql-dev \
    postgresql-client \
    gcc \
    musl-dev \
    linux-headers \
    curl \
    netcat-openbsd \
    bash

# Create non-root user for security
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001 -G appuser

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt

# Copy application code
COPY app/ ./app/

# Copy templates and static files
COPY templates/ ./templates/
COPY static/ ./static/

# Copy wait-for-db script
COPY wait-for-db.sh /usr/local/bin/wait-for-db.sh
RUN chmod +x /usr/local/bin/wait-for-db.sh

# Set ownership to non-root user
RUN chown -R appuser:appuser /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_APP=app.main:create_app \
    PORT=8080

# Expose application port
EXPOSE 8080

# Switch to non-root user
USER appuser

# Health check endpoint
HEALTHCHECK --interval=30s \
            --timeout=3s \
            --start-period=40s \
            --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Start the application with gunicorn (after waiting for PostgreSQL)
CMD ["/bin/bash", "-c", "wait-for-db.sh gunicorn --bind 0.0.0.0:8080 --workers 4 --threads 2 --timeout 60 --access-logfile - --error-logfile - 'app.main:create_app()'"]
