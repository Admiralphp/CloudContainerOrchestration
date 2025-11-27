#!/bin/bash

# Build and Push Docker Images for Final Exam
# This script builds all Docker images and pushes them to Docker Hub

set -e

DOCKER_USERNAME="mohamedessid"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=========================================="
echo "Building Docker Images - Final Exam"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running"
    exit 1
fi

# Login to Docker Hub
echo "Logging in to Docker Hub..."
docker login

echo ""

# Build Backend API
print_step "Building Backend API..."
cd "$PROJECT_ROOT/backend-api"
docker build -t $DOCKER_USERNAME/final-exam-api:latest .
docker tag $DOCKER_USERNAME/final-exam-api:latest $DOCKER_USERNAME/final-exam-api:v1.0
print_step "Pushing Backend API to Docker Hub..."
docker push $DOCKER_USERNAME/final-exam-api:latest
docker push $DOCKER_USERNAME/final-exam-api:v1.0
echo ""

# Build Analytics Backend
print_step "Building Analytics Backend..."
cd "$PROJECT_ROOT/backend-analytics"
docker build -t $DOCKER_USERNAME/final-exam-analytics:latest .
docker tag $DOCKER_USERNAME/final-exam-analytics:latest $DOCKER_USERNAME/final-exam-analytics:v1.0
print_step "Pushing Analytics Backend to Docker Hub..."
docker push $DOCKER_USERNAME/final-exam-analytics:latest
docker push $DOCKER_USERNAME/final-exam-analytics:v1.0
echo ""

# Build Frontend
print_step "Building Frontend..."
cd "$PROJECT_ROOT/frontend"
docker build -t $DOCKER_USERNAME/final-exam-frontend:latest .
docker tag $DOCKER_USERNAME/final-exam-frontend:latest $DOCKER_USERNAME/final-exam-frontend:v1.0
print_step "Pushing Frontend to Docker Hub..."
docker push $DOCKER_USERNAME/final-exam-frontend:latest
docker push $DOCKER_USERNAME/final-exam-frontend:v1.0
echo ""

echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Images pushed:"
echo "  - $DOCKER_USERNAME/final-exam-api:latest"
echo "  - $DOCKER_USERNAME/final-exam-api:v1.0"
echo "  - $DOCKER_USERNAME/final-exam-analytics:latest"
echo "  - $DOCKER_USERNAME/final-exam-analytics:v1.0"
echo "  - $DOCKER_USERNAME/final-exam-frontend:latest"
echo "  - $DOCKER_USERNAME/final-exam-frontend:v1.0"
echo ""
echo "Next steps:"
echo "  1. Deploy to K3s: ./scripts/install.sh"
echo "  2. Test microservices: ./scripts/test-microservices.sh"
echo ""
