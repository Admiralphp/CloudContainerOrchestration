#!/bin/bash

# Final Exam - Microservices Deployment Script
# This script deploys the complete microservices architecture on K3s

set -e

NAMESPACE="final-exam"
K8S_DIR="$(cd "$(dirname "$0")/.." && pwd)/k8s"

echo "=========================================="
echo "Final Exam - Microservices Deployment"
echo "=========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Step 1: Create namespace
print_step "Creating namespace: $NAMESPACE"
kubectl apply -f "$K8S_DIR/namespace.yaml"
echo ""

# Step 2: Deploy MongoDB StatefulSet
print_step "Deploying MongoDB StatefulSet (3 replicas)..."
kubectl apply -f "$K8S_DIR/mongodb-configmap.yaml"
kubectl apply -f "$K8S_DIR/mongodb-secret.yaml"
kubectl apply -f "$K8S_DIR/mongodb-headless-service.yaml"
kubectl apply -f "$K8S_DIR/mongodb-service.yaml"
kubectl apply -f "$K8S_DIR/mongodb-statefulset.yaml"
echo "Waiting for MongoDB pods to be ready (timeout: 180s)..."
kubectl wait --for=condition=ready pod -l app=mongodb -n $NAMESPACE --timeout=180s || print_warning "MongoDB pods not ready yet, continuing..."
echo ""

# Step 3: Deploy PostgreSQL StatefulSet
print_step "Deploying PostgreSQL StatefulSet (3 replicas)..."
kubectl apply -f "$K8S_DIR/postgres-configmap.yaml"
kubectl apply -f "$K8S_DIR/postgres-secret.yaml"
kubectl apply -f "$K8S_DIR/postgres-headless-service.yaml"
kubectl apply -f "$K8S_DIR/postgres-service.yaml"
kubectl apply -f "$K8S_DIR/postgres-statefulset.yaml"
echo "Waiting for PostgreSQL pods to be ready (timeout: 180s)..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=180s || print_warning "PostgreSQL pods not ready yet, continuing..."
echo ""

# Step 4: Deploy Analytics Backend
print_step "Deploying Analytics Backend (Microservice)..."
kubectl apply -f "$K8S_DIR/analytics-configmap.yaml"
kubectl apply -f "$K8S_DIR/analytics-secret.yaml"
kubectl apply -f "$K8S_DIR/analytics-service.yaml"
kubectl apply -f "$K8S_DIR/analytics-deployment.yaml"
kubectl apply -f "$K8S_DIR/analytics-hpa.yaml"
echo "Waiting for Analytics pods to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=analytics -n $NAMESPACE --timeout=120s || print_warning "Analytics pods not ready yet, continuing..."
echo ""

# Step 5: Deploy Backend API Gateway
print_step "Deploying Backend API Gateway..."
kubectl apply -f "$K8S_DIR/backend-api-configmap.yaml"
kubectl apply -f "$K8S_DIR/backend-api-secret.yaml"
kubectl apply -f "$K8S_DIR/backend-api-service.yaml"
kubectl apply -f "$K8S_DIR/backend-api-deployment.yaml"
kubectl apply -f "$K8S_DIR/backend-api-hpa.yaml"
echo "Waiting for Backend API pods to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=backend-api -n $NAMESPACE --timeout=120s || print_warning "Backend API pods not ready yet, continuing..."
echo ""

# Step 6: Deploy Frontend
print_step "Deploying Frontend..."
kubectl apply -f "$K8S_DIR/frontend-configmap.yaml"
kubectl apply -f "$K8S_DIR/frontend-service.yaml"
kubectl apply -f "$K8S_DIR/frontend-deployment.yaml"
kubectl apply -f "$K8S_DIR/frontend-hpa.yaml"
echo "Waiting for Frontend pods to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=120s || print_warning "Frontend pods not ready yet, continuing..."
echo ""

# Step 7: Display deployment status
print_step "Deployment Summary"
echo ""
echo "Namespaces:"
kubectl get ns | grep $NAMESPACE
echo ""
echo "StatefulSets:"
kubectl get statefulset -n $NAMESPACE
echo ""
echo "Deployments:"
kubectl get deployment -n $NAMESPACE
echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE
echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo "HPA Status:"
kubectl get hpa -n $NAMESPACE
echo ""
echo "PVCs:"
kubectl get pvc -n $NAMESPACE
echo ""

# Step 8: Get access information
NODE_PORT=$(kubectl get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Access the application at:"
echo "  Frontend: http://$NODE_IP:$NODE_PORT"
echo ""
echo "Internal Services:"
echo "  Backend API: http://backend-api-service.$NAMESPACE.svc.cluster.local:3000"
echo "  Analytics: http://analytics-service.$NAMESPACE.svc.cluster.local:4000"
echo "  PostgreSQL: postgres-service.$NAMESPACE.svc.cluster.local:5432"
echo "  MongoDB: mongodb-service.$NAMESPACE.svc.cluster.local:27017"
echo ""
echo "To check logs:"
echo "  kubectl logs -f -l app=frontend -n $NAMESPACE"
echo "  kubectl logs -f -l app=backend-api -n $NAMESPACE"
echo "  kubectl logs -f -l app=analytics -n $NAMESPACE"
echo ""
echo "To delete all resources:"
echo "  kubectl delete namespace $NAMESPACE"
echo ""
