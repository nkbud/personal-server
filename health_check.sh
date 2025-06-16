#!/bin/bash

# Supabase Health Check Script
# This script checks if all Supabase services are running properly

echo "🔍 Checking Supabase services health..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
        echo -e "${GREEN}✅ $service_name is healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ $service_name is not responding${NC}"
        return 1
    fi
}

# Check if Docker Compose is running
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose is not installed${NC}"
    exit 1
fi

# Check if services are running
echo "📋 Checking container status..."
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${RED}❌ Some services are not running${NC}"
    docker-compose ps
    exit 1
else
    echo -e "${GREEN}✅ All containers are running${NC}"
fi

# Check individual services
echo "🌐 Checking service endpoints..."

# Check Kong API Gateway
if ! check_service "Kong API Gateway" "http://localhost:8000" "404"; then
    echo -e "${YELLOW}ℹ️  Kong might be starting up, checking logs:${NC}"
    docker-compose logs --tail=5 kong
fi

# Check PostgREST
if ! check_service "PostgREST API" "http://localhost:3000"; then
    echo -e "${YELLOW}ℹ️  PostgREST might be starting up, checking logs:${NC}"
    docker-compose logs --tail=5 rest
fi

# Check Auth service
if ! check_service "Auth Service" "http://localhost:9999/health" "200"; then
    echo -e "${YELLOW}ℹ️  Auth service might be starting up, checking logs:${NC}"
    docker-compose logs --tail=5 auth
fi

# Check database connectivity
echo "🗄️  Checking database connectivity..."
if docker-compose exec -T db pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Database is accessible${NC}"
else
    echo -e "${RED}❌ Database is not accessible${NC}"
    docker-compose logs --tail=5 db
fi

# Check system resources
echo "💾 Checking system resources..."
memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

echo "Memory usage: ${memory_usage}%"
echo "Disk usage: ${disk_usage}%"

if (( $(echo "$memory_usage > 90" | bc -l) )); then
    echo -e "${RED}⚠️  High memory usage detected${NC}"
fi

if [ "$disk_usage" -gt 90 ]; then
    echo -e "${RED}⚠️  High disk usage detected${NC}"
fi

echo -e "${GREEN}🎉 Health check completed${NC}"