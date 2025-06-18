#!/bin/bash

# Health App Setup Script
set -e

echo "🚀 Health App Setup Script"
echo "=========================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p logs/frontend logs/api logs/mysql uploads

# Set permissions
chmod 755 logs uploads
chmod +x scripts/*.sh

# Copy environment file based on argument
ENV=${1:-dev}
echo "🔧 Setting up environment: $ENV"

if [ -f ".env.$ENV" ]; then
    cp ".env.$ENV" .env
    echo "✅ Environment file copied: .env.$ENV -> .env"
else
    echo "❌ Environment file not found: .env.$ENV"
    exit 1
fi

# Pull latest images
echo "📥 Pulling latest container images..."
docker-compose pull

# Start the environment
echo "🚀 Starting $ENV environment..."
case $ENV in
    dev)
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
        echo "✅ Development environment started!"
        echo "🌐 Frontend: http://localhost:8080"
        echo "🔗 API: http://localhost:3001"
        echo "🗄️  Database: localhost:3306"
        ;;
    test)
        docker-compose -f docker-compose.yml -f docker-compose.test.yml up -d
        echo "✅ Test environment started!"
        echo "🌐 Frontend: http://localhost:8081"
        echo "🔗 API: http://localhost:3002"
        echo "🗄️  Database: localhost:3307"
        ;;
    prod)
        docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
        echo "✅ Production environment started!"
        echo "⚠️  Make sure to configure proper secrets and environment variables!"
        ;;
    *)
        echo "❌ Unknown environment: $ENV"
        echo "Usage: $0 [dev|test|prod]"
        exit 1
        ;;
esac

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Check service health
echo "🔍 Checking service health..."
docker-compose ps

echo ""
echo "🎉 Setup complete!"
echo "📖 Run 'make help' to see available commands"