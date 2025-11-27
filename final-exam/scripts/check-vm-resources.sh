#!/bin/bash

# Check VM Resources Before Deployment
# This script verifies if VM has enough resources to run both applications

echo "=========================================="
echo "VM Resources Check"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_passed() {
    echo -e "${GREEN}✓ OK${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC} $1"
}

check_failed() {
    echo -e "${RED}✗ CRITICAL${NC} $1"
}

echo "1. Kubernetes Node Resources:"
echo "----------------------------------------"
kubectl top nodes 2>/dev/null || echo "Warning: metrics-server not available"
echo ""

echo "2. Node Capacity:"
echo "----------------------------------------"
kubectl describe nodes | grep -A 5 "Capacity:\|Allocatable:"
echo ""

echo "3. Storage Available:"
echo "----------------------------------------"
df -h | grep -E "Filesystem|/var/lib/rancher"
STORAGE_AVAILABLE=$(df -h /var/lib/rancher/k3s 2>/dev/null | awk 'NR==2 {print $4}' || echo "N/A")
echo ""
echo "Storage available for PVCs: $STORAGE_AVAILABLE"
echo ""

echo "4. Memory Available:"
echo "----------------------------------------"
free -h
MEMORY_AVAILABLE=$(free -h | awk 'NR==2 {print $7}')
echo ""
echo "Memory available: $MEMORY_AVAILABLE"
echo ""

echo "5. CPU Info:"
echo "----------------------------------------"
lscpu | grep -E "^CPU\(s\)|Model name|Thread"
echo ""

echo "6. Current Resource Usage:"
echo "----------------------------------------"
echo "Pods by namespace:"
kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c
echo ""
echo "PVC usage:"
kubectl get pvc --all-namespaces --no-headers | wc -l
echo ""

echo "7. Check for Conflicts:"
echo "----------------------------------------"
CHALLENGE_NS=$(kubectl get namespace three-tier-app 2>/dev/null)
FINAL_NS=$(kubectl get namespace final-exam 2>/dev/null)

if [ -n "$CHALLENGE_NS" ]; then
    check_warning "Challenge Lab (three-tier-app) is deployed"
    echo "  NodePort: 30080"
    kubectl get pods -n three-tier-app --no-headers | wc -l | xargs echo "  Pods:"
    kubectl get pvc -n three-tier-app --no-headers | wc -l | xargs echo "  PVCs:"
else
    echo "  Challenge Lab not deployed"
fi
echo ""

if [ -n "$FINAL_NS" ]; then
    check_warning "Final Exam (final-exam) is already deployed"
    echo "  NodePort: 30090"
    kubectl get pods -n final-exam --no-headers | wc -l | xargs echo "  Pods:"
    kubectl get pvc -n final-exam --no-headers | wc -l | xargs echo "  PVCs:"
else
    echo "  Final Exam not deployed"
fi
echo ""

echo "8. Resource Requirements Analysis:"
echo "----------------------------------------"
echo "Challenge Lab Requirements:"
echo "  - CPU: ~1.5 vCPU (6 pods)"
echo "  - Memory: ~2 GB"
echo "  - Storage: 30 Gi (PostgreSQL 3 replicas × 5Gi × 2)"
echo ""
echo "Final Exam Requirements:"
echo "  - CPU: ~2.5 vCPU (12 pods)"
echo "  - Memory: ~3 GB"
echo "  - Storage: 60 Gi (PostgreSQL 3×5Gi×2 + MongoDB 3×5Gi×2)"
echo ""
echo "Combined Requirements (if both deployed):"
echo "  - CPU: ~4 vCPU minimum"
echo "  - Memory: ~5-6 GB"
echo "  - Storage: ~90 Gi"
echo ""

echo "=========================================="
echo "Recommendations"
echo "=========================================="
echo ""

# Parse available resources
TOTAL_CPU=$(kubectl get nodes -o json | grep -oP '"cpu":\s*"\K[0-9]+' | head -1)
TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEMORY_GB=$((TOTAL_MEMORY_KB / 1024 / 1024))

echo "VM Capacity Detected:"
echo "  - CPU: ${TOTAL_CPU:-Unknown} cores"
echo "  - Memory: ${TOTAL_MEMORY_GB:-Unknown} GB"
echo "  - Storage: $STORAGE_AVAILABLE"
echo ""

if [ -n "$TOTAL_CPU" ] && [ "$TOTAL_CPU" -lt 4 ]; then
    check_warning "CPU may be insufficient for both applications"
    echo ""
    echo "OPTION 1: Reduce replicas in Final Exam"
    echo "  Edit k8s/mongodb-statefulset.yaml: replicas: 3 → 1"
    echo "  Edit k8s/postgres-statefulset.yaml: replicas: 3 → 1"
    echo "  This saves ~60Gi storage and ~1 vCPU"
    echo ""
    echo "OPTION 2: Delete Challenge Lab before deploying Final Exam"
    echo "  kubectl delete namespace three-tier-app"
    echo ""
    echo "OPTION 3: Deploy on separate VMs"
    echo ""
else
    check_passed "CPU resources appear sufficient"
fi

if [ -n "$TOTAL_MEMORY_GB" ] && [ "$TOTAL_MEMORY_GB" -lt 6 ]; then
    check_warning "Memory may be tight for both applications"
    echo "  Consider reducing replicas or deleting Challenge Lab first"
else
    check_passed "Memory resources appear sufficient"
fi

echo ""
echo "To proceed with deployment:"
echo "  1. If resources are sufficient: ./scripts/install.sh"
echo "  2. If resources are limited: ./scripts/install-minimal.sh (reduced replicas)"
echo "  3. If conflicts occur: kubectl delete namespace three-tier-app"
echo ""
