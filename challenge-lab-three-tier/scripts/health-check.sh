#!/bin/bash

# Couleurs pour l'output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Health Check - Three-Tier Application${NC}"
echo -e "${GREEN}========================================${NC}"

# Check Namespace
echo -e "\n${YELLOW}[1/7] Checking Namespace...${NC}"
if kubectl get namespace three-tier-app &> /dev/null; then
    echo -e "${GREEN}✓ Namespace exists${NC}"
else
    echo -e "${RED}✗ Namespace not found${NC}"
    exit 1
fi

# Check Database Pods
echo -e "\n${YELLOW}[2/7] Checking Database Pods...${NC}"
DB_READY=$(kubectl get pods -n three-tier-app -l app=postgres --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
DB_TOTAL=$(kubectl get pods -n three-tier-app -l app=postgres --no-headers 2>/dev/null | wc -l)
echo -e "Database Pods: ${GREEN}${DB_READY}/${DB_TOTAL} Running${NC}"

# Check Backend Pods
echo -e "\n${YELLOW}[3/7] Checking Backend Pods...${NC}"
BACKEND_READY=$(kubectl get pods -n three-tier-app -l app=backend --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
BACKEND_TOTAL=$(kubectl get pods -n three-tier-app -l app=backend --no-headers 2>/dev/null | wc -l)
echo -e "Backend Pods: ${GREEN}${BACKEND_READY}/${BACKEND_TOTAL} Running${NC}"

# Check Frontend Pods
echo -e "\n${YELLOW}[4/7] Checking Frontend Pods...${NC}"
FRONTEND_READY=$(kubectl get pods -n three-tier-app -l app=frontend --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
FRONTEND_TOTAL=$(kubectl get pods -n three-tier-app -l app=frontend --no-headers 2>/dev/null | wc -l)
echo -e "Frontend Pods: ${GREEN}${FRONTEND_READY}/${FRONTEND_TOTAL} Running${NC}"

# Check Services
echo -e "\n${YELLOW}[5/7] Checking Services...${NC}"
kubectl get svc -n three-tier-app

# Check PVCs
echo -e "\n${YELLOW}[6/7] Checking Persistent Volume Claims...${NC}"
kubectl get pvc -n three-tier-app

# Check HPA
echo -e "\n${YELLOW}[7/7] Checking Horizontal Pod Autoscaler...${NC}"
kubectl get hpa -n three-tier-app

# Test Backend API
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Backend API Endpoint${NC}"
echo -e "${BLUE}========================================${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo -e "\nBackend Health: ${YELLOW}http://${NODE_IP}:30001/api/health${NC}"
curl -s http://${NODE_IP}:30001/api/health | jq . 2>/dev/null || curl -s http://${NODE_IP}:30001/api/health

echo -e "\n\n${GREEN}========================================${NC}"
echo -e "${GREEN}Access URLs${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Frontend: ${GREEN}http://${NODE_IP}:30000${NC}"
echo -e "Backend:  ${GREEN}http://${NODE_IP}:30001${NC}"
