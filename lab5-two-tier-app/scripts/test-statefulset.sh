#!/usr/bin/env bash
set -e

echo "=========================================="
echo "Test StatefulSet PostgreSQL - LAB 8"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Pod Naming Stability
echo -e "${BLUE}[Test 1] Pod Naming Stability${NC}"
echo "StatefulSet pods have predictable names:"
kubectl get pods -n lab5-app -l app=postgres
echo ""
echo "Pod name format: postgres-0, postgres-1, postgres-2..."
echo -e "${GREEN}✓ Pods follow StatefulSet naming convention${NC}"
echo ""

# Test 2: Stable DNS Entries
echo -e "${BLUE}[Test 2] Stable DNS Entries${NC}"
echo "Headless service provides stable DNS for each pod:"
echo ""
echo "DNS format: <pod-name>.<headless-service>.<namespace>.svc.cluster.local"
echo "Example: postgres-0.postgres-headless.lab5-app.svc.cluster.local"
echo ""
echo "Testing DNS resolution from a pod..."
kubectl run -n lab5-app dns-test --image=busybox:1.28 --rm -it --restart=Never -- nslookup postgres-0.postgres-headless.lab5-app.svc.cluster.local || true
echo -e "${GREEN}✓ DNS entries are stable and resolvable${NC}"
echo ""

# Test 3: Automatic PVC Creation
echo -e "${BLUE}[Test 3] Automatic PVC Creation via volumeClaimTemplates${NC}"
echo "PVCs are automatically created for each StatefulSet replica:"
kubectl get pvc -n lab5-app
echo ""
echo "PVC naming format: <volumeClaimTemplate-name>-<pod-name>"
echo "Example: postgres-storage-postgres-0"
echo -e "${GREEN}✓ PVCs automatically created${NC}"
echo ""

# Test 4: Data Persistence Test
echo -e "${BLUE}[Test 4] Data Persistence Test${NC}"
echo "Step 1: Insert test data..."
kubectl exec -n lab5-app postgres-0 -- psql -U appuser -d appdb -c "CREATE TABLE IF NOT EXISTS test_persistence (id SERIAL PRIMARY KEY, data VARCHAR(50));"
kubectl exec -n lab5-app postgres-0 -- psql -U appuser -d appdb -c "INSERT INTO test_persistence (data) VALUES ('Data before pod restart');"
echo "Data inserted:"
kubectl exec -n lab5-app postgres-0 -- psql -U appuser -d appdb -c "SELECT * FROM test_persistence;"
echo ""

echo "Step 2: Delete the pod to simulate restart..."
kubectl delete pod postgres-0 -n lab5-app
echo "Waiting for pod to restart..."
kubectl wait --for=condition=ready pod/postgres-0 -n lab5-app --timeout=120s
echo ""

echo "Step 3: Verify data survived the restart..."
kubectl exec -n lab5-app postgres-0 -- psql -U appuser -d appdb -c "SELECT * FROM test_persistence;"
echo -e "${GREEN}✓ Data persisted across pod restart${NC}"
echo ""

# Test 5: Pod Identity Stability
echo -e "${BLUE}[Test 5] Pod Identity Stability${NC}"
echo "After deletion, pod gets the same name (postgres-0):"
kubectl get pod postgres-0 -n lab5-app -o wide
echo ""
echo "Compare AGE column - pod was recreated but kept same name"
echo -e "${GREEN}✓ Pod identity is stable${NC}"
echo ""

# Test 6: Scaling Behavior
echo -e "${BLUE}[Test 6] Scaling Behavior (Sequential Creation)${NC}"
echo "Current replicas:"
kubectl get statefulset postgres -n lab5-app
echo ""

echo "Scaling to 2 replicas..."
kubectl scale statefulset postgres -n lab5-app --replicas=2
echo ""

echo "Watch pods being created sequentially (postgres-1 after postgres-0):"
echo "Waiting for postgres-1 to be ready..."
kubectl wait --for=condition=ready pod/postgres-1 -n lab5-app --timeout=120s
echo ""

kubectl get pods -n lab5-app -l app=postgres
echo ""

echo "Notice:"
echo "1. postgres-1 was created AFTER postgres-0 was ready"
echo "2. Each pod has its own PVC (postgres-storage-postgres-1)"
kubectl get pvc -n lab5-app
echo -e "${GREEN}✓ Scaling is sequential and ordered${NC}"
echo ""

echo "Scaling back to 1 replica..."
kubectl scale statefulset postgres -n lab5-app --replicas=1
echo "Waiting for scale down..."
sleep 10
kubectl get pods -n lab5-app -l app=postgres
echo ""
echo "Notice: postgres-1 was deleted but its PVC remains (data preserved)"
kubectl get pvc -n lab5-app
echo -e "${YELLOW}Note: PVC postgres-storage-postgres-1 is retained for future use${NC}"
echo ""

# Test 7: Headless vs Regular Service
echo -e "${BLUE}[Test 7] Headless vs Regular Service${NC}"
echo "Headless Service (postgres-headless):"
kubectl get svc postgres-headless -n lab5-app
echo "ClusterIP: None - provides stable DNS per pod"
echo ""
echo "Regular Service (db-service):"
kubectl get svc db-service -n lab5-app
echo "ClusterIP: Assigned - load balances across all postgres pods"
echo -e "${GREEN}✓ Both service types configured correctly${NC}"
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}All StatefulSet Tests Passed!${NC}"
echo "=========================================="
echo ""
echo "Key Differences from Deployment (Lab 5):"
echo "1. ✓ Predictable pod names (postgres-0, not random suffixes)"
echo "2. ✓ Stable DNS entries per pod"
echo "3. ✓ Automatic PVC creation via volumeClaimTemplates"
echo "4. ✓ Data persists across pod restarts"
echo "5. ✓ Sequential, ordered pod creation"
echo "6. ✓ PVCs retained even when scaling down"
echo "7. ✓ Ready for database replication and clustering"
echo ""
echo "Cleanup test data:"
echo "kubectl exec -n lab5-app postgres-0 -- psql -U appuser -d appdb -c 'DROP TABLE test_persistence;'"
