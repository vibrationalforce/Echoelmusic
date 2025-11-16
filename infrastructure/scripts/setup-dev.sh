#!/bin/bash

# Echoelmusic Development Environment Setup Script

set -e

echo "🚀 Echoelmusic Development Environment Setup"
echo "============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is installed${NC}"

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker Compose is installed${NC}"
echo ""

# Create .env file from template if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}📝 Creating .env file from template...${NC}"
    cp .env.template .env
    echo -e "${GREEN}✅ .env file created${NC}"
    echo -e "${YELLOW}⚠️  Please edit .env and add your API keys before starting services${NC}"
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

echo ""

# Install backend dependencies
if [ -f backend/package.json ]; then
    echo -e "${YELLOW}📦 Installing backend dependencies...${NC}"
    cd backend
    npm install
    cd ..
    echo -e "${GREEN}✅ Backend dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Backend package.json not found, skipping...${NC}"
fi

echo ""

# Install contract dependencies
if [ -f contracts/package.json ]; then
    echo -e "${YELLOW}📦 Installing contract dependencies...${NC}"
    cd contracts
    npm install
    cd ..
    echo -e "${GREEN}✅ Contract dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Contracts package.json not found, skipping...${NC}"
fi

echo ""

# Start Docker containers
echo -e "${YELLOW}🐳 Starting Docker containers...${NC}"
cd infrastructure/docker
docker-compose up -d

echo ""
echo -e "${GREEN}✅ Docker containers started successfully!${NC}"
echo ""

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 10

# Check service health
echo ""
echo -e "${GREEN}🏥 Service Status:${NC}"
docker-compose ps

echo ""
echo -e "${GREEN}🎉 Development environment is ready!${NC}"
echo ""
echo "📋 Available Services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🗄️  PostgreSQL:     localhost:5432"
echo "  🔴 Redis:           localhost:6379"
echo "  📦 IPFS:            localhost:5001 (API), localhost:8080 (Gateway)"
echo "  🌐 Backend API:     http://localhost:3000"
echo "  ⛓️  Hardhat Node:    http://localhost:8545"
echo "  🎛️  pgAdmin:         http://localhost:5050"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 Next Steps:"
echo "  1. Edit .env and add your API keys"
echo "  2. Run database migrations: cd backend && npm run migrate"
echo "  3. Start backend dev server: cd backend && npm run dev"
echo "  4. Deploy contracts: cd contracts && npm run deploy:localhost"
echo ""
echo "🛑 To stop services: cd infrastructure/docker && docker-compose down"
echo "📊 To view logs: cd infrastructure/docker && docker-compose logs -f"
echo ""
