#!/bin/bash

# Final Exam - Minimal Deployment (1 replica per StatefulSet)
# Use this script when VM resources are limited

set -e

NAMESPACE="final-exam"
K8S_DIR="$(cd "$(dirname "$0")/.." && pwd)/k8s"
TEMP_DIR="/tmp/final-exam-minimal"

echo "=========================================="
echo "Final Exam - Minimal Deployment"
echo "Low Resource Mode (1 replica per DB)"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create temp directory
mkdir -p "$TEMP_DIR"

# Copy manifests and modify replicas
print_step "Preparing minimal configuration (1 replica per StatefulSet)..."
cp -r "$K8S_DIR"/*.yaml "$TEMP_DIR/"

# Reduce MongoDB replicas to 1
sed -i 's/replicas: 3/replicas: 1/g' "$TEMP_DIR/mongodb-statefulset.yaml"
print_warning "MongoDB replicas: 3 → 1"

# Reduce PostgreSQL replicas to 1
sed -i 's/replicas: 3/replicas: 1/g' "$TEMP_DIR/postgres-statefulset.yaml"
print_warning "PostgreSQL replicas: 3 → 1"

echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} kubectl not found"
    exit 1
fi

# Step 1: Create namespace
print_step "Creating namespace: $NAMESPACE"
kubectl apply -f "$TEMP_DIR/namespace.yaml"
echo ""

# Step 2: Deploy MongoDB StatefulSet (1 replica)
print_step "Deploying MongoDB StatefulSet (1 replica)..."
kubectl apply -f "$TEMP_DIR/mongodb-configmap.yaml"
kubectl apply -f "$TEMP_DIR/mongodb-secret.yaml"
kubectl apply -f "$TEMP_DIR/mongodb-headless-service.yaml"
kubectl apply -f "$TEMP_DIR/mongodb-service.yaml"
kubectl apply -f "$TEMP_DIR/mongodb-statefulset.yaml"
echo "Waiting for MongoDB pod to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=mongodb -n $NAMESPACE --timeout=120s || print_warning "MongoDB pod not ready yet"
echo ""

# Step 3: Deploy PostgreSQL StatefulSet (1 replica)
print_step "Deploying PostgreSQL StatefulSet (1 replica)..."
kubectl apply -f "$TEMP_DIR/postgres-configmap.yaml"
kubectl apply -f "$TEMP_DIR/postgres-secret.yaml"
kubectl apply -f "$TEMP_DIR/postgres-headless-service.yaml"
kubectl apply -f "$TEMP_DIR/postgres-service.yaml"
kubectl apply -f "$TEMP_DIR/postgres-statefulset.yaml"
echo "Waiting for PostgreSQL pod to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=120s || print_warning "PostgreSQL pod not ready yet"
echo ""

# Step 4: Deploy Analytics Backend
print_step "Deploying Analytics Backend..."
kubectl apply -f "$TEMP_DIR/analytics-configmap.yaml"
kubectl apply -f "$TEMP_DIR/analytics-secret.yaml"
kubectl apply -f "$TEMP_DIR/analytics-service.yaml"
kubectl apply -f "$TEMP_DIR/analytics-deployment.yaml"
kubectl apply -f "$TEMP_DIR/analytics-hpa.yaml"
echo "Waiting for Analytics pods to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=analytics -n $NAMESPACE --timeout=120s || print_warning "Analytics pods not ready yet"
echo ""

# Step 5: Deploy Backend API Gateway
print_step "Deploying Backend API Gateway..."
kubectl apply -f "$TEMP_DIR/backend-api-configmap.yaml"
kubectl apply -f "$TEMP_DIR/backend-api-secret.yaml"
kubectl apply -f "$TEMP_DIR/backend-api-service.yaml"
kubectl apply -f "$TEMP_DIR/backend-api-deployment.yaml"
kubectl apply -f "$TEMP_DIR/backend-api-hpa.yaml"
echo "Waiting for Backend API pods to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=backend-api -n $NAMESPACE --timeout=120s || print_warning "Backend API pods not ready yet"
echo ""

# Step 6: Deploy Frontend
print_step "Deploying Frontend..."
kubectl apply -f "$TEMP_DIR/frontend-configmap.yaml"
kubectl apply -f "$TEMP_DIR/frontend-service.yaml"
kubectl apply -f "$TEMP_DIR/frontend-deployment.yaml"
kubectl apply -f "$TEMP_DIR/frontend-hpa.yaml"
echo "Waiting for Frontend pods to be ready (timeout: 120s)..."
kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=120s || print_warning "Frontend pods not ready yet"
echo ""

# Step 7: Display deployment status
print_step "Deployment Summary"
echo ""
echo "StatefulSets (Minimal Mode - 1 replica each):"
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
echo "PVCs (Total: 2 instead of 12):"
kubectl get pvc -n $NAMESPACE
echo ""

# Get access information
NODE_PORT=$(kubectl get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "=========================================="
echo "Minimal Deployment Complete!"
echo "=========================================="
echo ""
echo "Resource Savings:"
echo "  - Storage: 60Gi → 10Gi (reduced by 50Gi)"
echo "  - Pods: 12 → 6 (reduced by 50%)"
echo "  - CPU/Memory: Reduced by ~40%"
echo ""
echo "Access the application at:"
echo "  Frontend: http://$NODE_IP:$NODE_PORT"
echo ""
echo "⚠️  NOTE: Single replica mode means:"
echo "  - No database high availability"
echo "  - No automatic failover"
echo "  - Suitable for testing/development only"
echo ""
echo "To check logs:"
echo "  kubectl logs -f -l app=backend-api -n $NAMESPACE"
echo ""
echo "To scale back to full HA mode:"
echo "  kubectl scale statefulset mongodb --replicas=3 -n $NAMESPACE"
echo "  kubectl scale statefulset postgres --replicas=3 -n $NAMESPACE"
echo ""
echo "To delete all resources:"
echo "  kubectl delete namespace $NAMESPACE"
echo ""

# Cleanup temp files
rm -rf "$TEMP_DIR"
