#!/bin/bash

# Couleurs pour l'output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Three-Tier Application Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Namespace
echo -e "\n${YELLOW}[1/10] Creating namespace...${NC}"
kubectl apply -f k8s/namespace.yaml --validate=false

# ConfigMaps
echo -e "\n${YELLOW}[2/10] Creating ConfigMaps...${NC}"
kubectl apply -f k8s/db-configmap.yaml --validate=false
kubectl apply -f k8s/backend-configmap.yaml --validate=false
kubectl apply -f k8s/frontend-configmap.yaml --validate=false

# Secrets
echo -e "\n${YELLOW}[3/10] Creating Secrets...${NC}"
kubectl apply -f k8s/db-secret.yaml --validate=false

# Database Layer (StatefulSet)
echo -e "\n${YELLOW}[4/10] Deploying Database StatefulSet...${NC}"
kubectl apply -f k8s/postgres-headless-service.yaml --validate=false
kubectl apply -f k8s/postgres-statefulset.yaml --validate=false
kubectl apply -f k8s/postgres-service.yaml --validate=false

echo -e "\n${YELLOW}Waiting for database pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n three-tier-app --timeout=180s

# Backend Layer (Deployment + HPA)
echo -e "\n${YELLOW}[5/10] Deploying Backend API...${NC}"
kubectl apply -f k8s/backend-deployment.yaml --validate=false
kubectl apply -f k8s/backend-service.yaml --validate=false

echo -e "\n${YELLOW}Waiting for backend pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=backend -n three-tier-app --timeout=120s

echo -e "\n${YELLOW}[6/10] Creating Backend HPA...${NC}"
kubectl apply -f k8s/backend-hpa.yaml --validate=false

# Frontend Layer (Deployment)
echo -e "\n${YELLOW}[7/10] Deploying Frontend...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml --validate=false
kubectl apply -f k8s/frontend-service.yaml --validate=false

echo -e "\n${YELLOW}Waiting for frontend pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=frontend -n three-tier-app --timeout=120s

# Verification
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}[8/10] Pods Status:${NC}"
kubectl get pods -n three-tier-app -o wide

echo -e "\n${YELLOW}[9/10] Services:${NC}"
kubectl get svc -n three-tier-app

echo -e "\n${YELLOW}[10/10] PVCs:${NC}"
kubectl get pvc -n three-tier-app

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Access Information${NC}"
echo -e "${GREEN}========================================${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo -e "Frontend: ${GREEN}http://${NODE_IP}:30000${NC}"
echo -e "Backend:  ${GREEN}http://${NODE_IP}:30001/api/health${NC}"
echo -e "\n${GREEN}Deployment completed successfully! 🚀${NC}"
