#!/bin/bash

# Health Check Script for Final Exam Microservices
# Verifies all services are running and healthy

NAMESPACE="final-exam"

echo "=========================================="
echo "Health Check - Final Exam Microservices"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_passed() {
    echo -e "${GREEN}✓ HEALTHY${NC} $1"
}

check_failed() {
    echo -e "${RED}✗ UNHEALTHY${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC} $1"
}

# Check namespace
echo "Checking namespace: $NAMESPACE"
if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    check_passed "Namespace exists"
else
    check_failed "Namespace not found"
    exit 1
fi
echo ""

# Check StatefulSets
echo "Checking StatefulSets:"
MONGO_READY=$(kubectl get statefulset mongodb -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
MONGO_DESIRED=$(kubectl get statefulset mongodb -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$MONGO_READY" -eq "$MONGO_DESIRED" ] && [ "$MONGO_READY" -gt 0 ]; then
    check_passed "MongoDB: $MONGO_READY/$MONGO_DESIRED replicas ready"
else
    check_failed "MongoDB: $MONGO_READY/$MONGO_DESIRED replicas ready"
fi

POSTGRES_READY=$(kubectl get statefulset postgres -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
POSTGRES_DESIRED=$(kubectl get statefulset postgres -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$POSTGRES_READY" -eq "$POSTGRES_DESIRED" ] && [ "$POSTGRES_READY" -gt 0 ]; then
    check_passed "PostgreSQL: $POSTGRES_READY/$POSTGRES_DESIRED replicas ready"
else
    check_failed "PostgreSQL: $POSTGRES_READY/$POSTGRES_DESIRED replicas ready"
fi
echo ""

# Check Deployments
echo "Checking Deployments:"
ANALYTICS_READY=$(kubectl get deployment analytics -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
ANALYTICS_DESIRED=$(kubectl get deployment analytics -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$ANALYTICS_READY" -eq "$ANALYTICS_DESIRED" ] && [ "$ANALYTICS_READY" -gt 0 ]; then
    check_passed "Analytics: $ANALYTICS_READY/$ANALYTICS_DESIRED replicas ready"
else
    check_failed "Analytics: $ANALYTICS_READY/$ANALYTICS_DESIRED replicas ready"
fi

API_READY=$(kubectl get deployment backend-api -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
API_DESIRED=$(kubectl get deployment backend-api -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$API_READY" -eq "$API_DESIRED" ] && [ "$API_READY" -gt 0 ]; then
    check_passed "Backend API: $API_READY/$API_DESIRED replicas ready"
else
    check_failed "Backend API: $API_READY/$API_DESIRED replicas ready"
fi

FRONTEND_READY=$(kubectl get deployment frontend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
FRONTEND_DESIRED=$(kubectl get deployment frontend -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
if [ "$FRONTEND_READY" -eq "$FRONTEND_DESIRED" ] && [ "$FRONTEND_READY" -gt 0 ]; then
    check_passed "Frontend: $FRONTEND_READY/$FRONTEND_DESIRED replicas ready"
else
    check_failed "Frontend: $FRONTEND_READY/$FRONTEND_DESIRED replicas ready"
fi
echo ""

# Check Services
echo "Checking Services:"
kubectl get svc -n $NAMESPACE --no-headers | while read line; do
    SVC_NAME=$(echo $line | awk '{print $1}')
    check_passed "Service: $SVC_NAME"
done
echo ""

# Check Pods Status
echo "Checking Pods:"
kubectl get pods -n $NAMESPACE --no-headers | while read line; do
    POD_NAME=$(echo $line | awk '{print $1}')
    POD_STATUS=$(echo $line | awk '{print $3}')
    POD_READY=$(echo $line | awk '{print $2}')
    
    if [ "$POD_STATUS" = "Running" ]; then
        check_passed "Pod $POD_NAME: $POD_STATUS ($POD_READY)"
    elif [ "$POD_STATUS" = "Pending" ] || [ "$POD_STATUS" = "ContainerCreating" ]; then
        check_warning "Pod $POD_NAME: $POD_STATUS"
    else
        check_failed "Pod $POD_NAME: $POD_STATUS"
    fi
done
echo ""

# Check HPA Status
echo "Checking HorizontalPodAutoscalers:"
kubectl get hpa -n $NAMESPACE --no-headers 2>/dev/null | while read line; do
    HPA_NAME=$(echo $line | awk '{print $1}')
    CURRENT=$(echo $line | awk '{print $4}')
    MIN=$(echo $line | awk '{print $5}')
    MAX=$(echo $line | awk '{print $6}')
    check_passed "HPA $HPA_NAME: Current=$CURRENT, Min=$MIN, Max=$MAX"
done
echo ""

# Check PVCs
echo "Checking PersistentVolumeClaims:"
kubectl get pvc -n $NAMESPACE --no-headers | while read line; do
    PVC_NAME=$(echo $line | awk '{print $1}')
    PVC_STATUS=$(echo $line | awk '{print $2}')
    PVC_CAPACITY=$(echo $line | awk '{print $4}')
    
    if [ "$PVC_STATUS" = "Bound" ]; then
        check_passed "PVC $PVC_NAME: $PVC_STATUS ($PVC_CAPACITY)"
    else
        check_failed "PVC $PVC_NAME: $PVC_STATUS"
    fi
done
echo ""

# Test HTTP endpoints
echo "Testing HTTP Endpoints:"
API_POD=$(kubectl get pod -n $NAMESPACE -l app=backend-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$API_POD" ]; then
    if kubectl exec -n $NAMESPACE $API_POD -- curl -s -f http://localhost:3000/health > /dev/null 2>&1; then
        check_passed "Backend API /health endpoint responding"
    else
        check_failed "Backend API /health endpoint not responding"
    fi
fi

ANALYTICS_POD=$(kubectl get pod -n $NAMESPACE -l app=analytics -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$ANALYTICS_POD" ]; then
    if kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s -f http://localhost:4000/health > /dev/null 2>&1; then
        check_passed "Analytics Service /health endpoint responding"
    else
        check_failed "Analytics Service /health endpoint not responding"
    fi
fi
echo ""

# Access Information
NODE_PORT=$(kubectl get svc frontend-service -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

echo "=========================================="
echo "Health Check Complete"
echo "=========================================="
echo ""
echo "Access Information:"
echo "  Frontend URL: http://$NODE_IP:$NODE_PORT"
echo ""
echo "To view logs:"
echo "  kubectl logs -l app=backend-api -n $NAMESPACE"
echo "  kubectl logs -l app=analytics -n $NAMESPACE"
echo ""
