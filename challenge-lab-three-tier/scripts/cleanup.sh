#!/bin/bash

# Couleurs pour l'output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}Cleaning Up Three-Tier Application${NC}"
echo -e "${RED}========================================${NC}"

echo -e "\n${YELLOW}Deleting namespace (this will remove all resources)...${NC}"
kubectl delete namespace three-tier-app

echo -e "\n${YELLOW}Waiting for namespace deletion...${NC}"
kubectl wait --for=delete namespace/three-tier-app --timeout=120s

echo -e "\n${RED}Cleanup completed! All resources have been removed.${NC}"
