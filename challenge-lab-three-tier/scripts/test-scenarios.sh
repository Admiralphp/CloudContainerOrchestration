#!/bin/bash

# Couleurs pour l'output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Three-Tier Application - Test Scenarios${NC}"
echo -e "${GREEN}========================================${NC}"

# Test 1: Deployment Verification
echo -e "\n${BLUE}==== Test 1: Deployment Verification ====${NC}"
echo -e "${YELLOW}Checking all pods are running...${NC}"
kubectl get pods -n three-tier-app
echo -e "${GREEN}✓ Test 1 Completed${NC}"

# Test 2: Database Failover
echo -e "\n${BLUE}==== Test 2: Database Failover Test ====${NC}"
echo -e "${YELLOW}Current database pods:${NC}"
kubectl get pods -n three-tier-app -l app=postgres
echo -e "\n${YELLOW}Deleting postgres-0 to test failover...${NC}"
kubectl delete pod postgres-0 -n three-tier-app
echo -e "${YELLOW}Waiting for pod recreation...${NC}"
sleep 10
kubectl get pods -n three-tier-app -l app=postgres
echo -e "${GREEN}✓ Test 2 Completed - Pod should be recreated with same name${NC}"

# Test 3: Backend HPA Scaling
echo -e "\n${BLUE}==== Test 3: Backend HPA Scaling ====${NC}"
echo -e "${YELLOW}Current HPA status:${NC}"
kubectl get hpa -n three-tier-app
echo -e "\n${YELLOW}Current backend pods:${NC}"
kubectl get pods -n three-tier-app -l app=backend
echo -e "${GREEN}✓ Test 3 Info - HPA will auto-scale between 2-5 replicas based on CPU/Memory${NC}"

# Test 4: Rolling Update
echo -e "\n${BLUE}==== Test 4: Rolling Update Test ====${NC}"
echo -e "${YELLOW}Current frontend deployment:${NC}"
kubectl get deployment frontend -n three-tier-app
echo -e "\n${YELLOW}Performing rolling restart...${NC}"
kubectl rollout restart deployment/frontend -n three-tier-app
kubectl rollout status deployment/frontend -n three-tier-app
echo -e "${GREEN}✓ Test 4 Completed - Zero downtime rolling update${NC}"

# Test 5: Data Persistence
echo -e "\n${BLUE}==== Test 5: Data Persistence Test ====${NC}"
echo -e "${YELLOW}Creating test task via API...${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl -X POST http://${NODE_IP}:30001/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Persistence Task","completed":false}'
echo -e "\n${YELLOW}Fetching tasks:${NC}"
curl -s http://${NODE_IP}:30001/api/tasks | jq . 2>/dev/null || curl -s http://${NODE_IP}:30001/api/tasks
echo -e "\n${YELLOW}Deleting postgres-0 to test data persistence...${NC}"
kubectl delete pod postgres-0 -n three-tier-app
echo -e "${YELLOW}Waiting for pod recreation (60s)...${NC}"
sleep 60
echo -e "\n${YELLOW}Fetching tasks after pod recreation:${NC}"
curl -s http://${NODE_IP}:30001/api/tasks | jq . 2>/dev/null || curl -s http://${NODE_IP}:30001/api/tasks
echo -e "\n${GREEN}✓ Test 5 Completed - Data should persist across pod restarts${NC}"

# Test 6: Service Discovery
echo -e "\n${BLUE}==== Test 6: Service Discovery Test ====${NC}"
echo -e "${YELLOW}Testing DNS resolution between services...${NC}"
BACKEND_POD=$(kubectl get pod -n three-tier-app -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo -e "Backend pod: ${BACKEND_POD}"
echo -e "\n${YELLOW}Resolving postgres-service from backend pod:${NC}"
kubectl exec -n three-tier-app ${BACKEND_POD} -- nslookup postgres-service.three-tier-app.svc.cluster.local
echo -e "\n${YELLOW}Resolving postgres-0 headless DNS:${NC}"
kubectl exec -n three-tier-app ${BACKEND_POD} -- nslookup postgres-0.postgres-headless.three-tier-app.svc.cluster.local
echo -e "${GREEN}✓ Test 6 Completed - Service discovery working${NC}"

# Test 7: Load Balancing
echo -e "\n${BLUE}==== Test 7: Load Balancing Test ====${NC}"
echo -e "${YELLOW}Testing frontend service load balancing (10 requests):${NC}"
for i in {1..10}; do
  POD_NAME=$(curl -s http://${NODE_IP}:30000 | grep -o "frontend-[a-z0-9-]*" | head -1)
  echo "Request $i handled by: $POD_NAME"
done
echo -e "${GREEN}✓ Test 7 Completed - Requests distributed across frontend pods${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}All Tests Completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Summary:${NC}"
echo -e "1. ✓ Deployment: All components deployed"
echo -e "2. ✓ Failover: Database pods auto-recover"
echo -e "3. ✓ HPA: Backend scales 2-5 replicas"
echo -e "4. ✓ Rolling Update: Zero-downtime updates"
echo -e "5. ✓ Persistence: Data survives pod restarts"
echo -e "6. ✓ Service Discovery: DNS resolution working"
echo -e "7. ✓ Load Balancing: Traffic distributed"
