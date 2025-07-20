#!/bin/bash

# Test script to validate Supabase configuration
# This script performs basic validation without actually starting services

echo "🧪 Testing Supabase configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if file exists and has content
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ] && [ -s "$file" ]; then
        echo -e "${GREEN}✅ $description exists and has content${NC}"
        return 0
    else
        echo -e "${RED}❌ $description is missing or empty${NC}"
        return 1
    fi
}

# Check required files
echo "📁 Checking required files..."
check_file "docker-compose.yml" "Docker Compose file"
check_file ".env.example" "Environment template"
check_file "config/kong.yml" "Kong configuration"
check_file "init/init.sql" "Database initialization script"
check_file "DEPLOY.md" "Deployment guide"
check_file "health_check.sh" "Health check script"

# Validate YAML syntax
echo "🔍 Validating YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null; then
    echo -e "${GREEN}✅ docker-compose.yml has valid YAML syntax${NC}"
else
    echo -e "${RED}❌ docker-compose.yml has invalid YAML syntax${NC}"
fi

if python3 -c "import yaml; yaml.safe_load(open('config/kong.yml'))" 2>/dev/null; then
    echo -e "${GREEN}✅ kong.yml has valid YAML syntax${NC}"
else
    echo -e "${RED}❌ kong.yml has invalid YAML syntax${NC}"
fi

# Check if health check script is executable
if [ -x "health_check.sh" ]; then
    echo -e "${GREEN}✅ health_check.sh is executable${NC}"
else
    echo -e "${YELLOW}⚠️  health_check.sh is not executable (will be fixed)${NC}"
    chmod +x health_check.sh
fi

# Check for required environment variables in .env.example
echo "🔧 Checking environment template..."
required_vars=("POSTGRES_PASSWORD" "JWT_SECRET" "API_EXTERNAL_URL" "SITE_URL")
for var in "${required_vars[@]}"; do
    if grep -q "^$var=" .env.example; then
        echo -e "${GREEN}✅ $var is defined in .env.example${NC}"
    else
        echo -e "${RED}❌ $var is missing from .env.example${NC}"
    fi
done

# Check Docker Compose service definitions
echo "🐳 Checking Docker Compose services..."
services=("db" "rest" "auth" "kong")
for service in "${services[@]}"; do
    if grep -q "^[[:space:]]*$service:" docker-compose.yml; then
        echo -e "${GREEN}✅ Service '$service' is defined${NC}"
    else
        echo -e "${RED}❌ Service '$service' is missing${NC}"
    fi
done

# Check for memory optimizations in PostgreSQL
echo "💾 Checking memory optimizations..."
if grep -q "shared_buffers=64MB" docker-compose.yml; then
    echo -e "${GREEN}✅ PostgreSQL memory optimizations are configured${NC}"
else
    echo -e "${YELLOW}⚠️  PostgreSQL memory optimizations may be missing${NC}"
fi

# Check Kong configuration
echo "🌐 Checking Kong configuration..."
if grep -q "auth-v1" config/kong.yml && grep -q "rest-v1" config/kong.yml; then
    echo -e "${GREEN}✅ Kong routes are configured for auth and rest services${NC}"
else
    echo -e "${RED}❌ Kong routes configuration may be incomplete${NC}"
fi

# Check SQL initialization
echo "🗄️  Checking database initialization..."
if grep -q "create extension" init/init.sql && grep -q "create role" init/init.sql; then
    echo -e "${GREEN}✅ Database initialization script includes extensions and roles${NC}"
else
    echo -e "${RED}❌ Database initialization script may be incomplete${NC}"
fi

echo -e "${GREEN}🎯 Configuration validation completed${NC}"
echo ""
echo "📖 Next steps:"
echo "1. Copy .env.example to .env and configure your values"
echo "2. Follow the deployment guide in DEPLOY.md"
echo "3. Run docker-compose up -d to start services"
echo "4. Use ./health_check.sh to monitor service health"