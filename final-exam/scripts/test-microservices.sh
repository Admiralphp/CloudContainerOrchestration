#!/bin/bash

# Test Microservices Communication
# This script validates the REST API communication between services

set -e

NAMESPACE="final-exam"

echo "=========================================="
echo "Testing Microservices Communication"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_passed() {
    echo -e "${GREEN}✓ PASSED${NC} $1"
}

test_failed() {
    echo -e "${RED}✗ FAILED${NC} $1"
}

test_info() {
    echo -e "${YELLOW}ℹ INFO${NC} $1"
}

# Get service endpoints
API_POD=$(kubectl get pod -n $NAMESPACE -l app=backend-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
ANALYTICS_POD=$(kubectl get pod -n $NAMESPACE -l app=analytics -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$API_POD" ]; then
    test_failed "Backend API pod not found"
    exit 1
fi

if [ -z "$ANALYTICS_POD" ]; then
    test_failed "Analytics pod not found"
    exit 1
fi

test_info "Using Backend API pod: $API_POD"
test_info "Using Analytics pod: $ANALYTICS_POD"
echo ""

# Test 1: Backend API Health
echo "Test 1: Backend API Health Check"
if kubectl exec -n $NAMESPACE $API_POD -- curl -s -f http://localhost:3000/health > /dev/null 2>&1; then
    test_passed "Backend API is healthy"
else
    test_failed "Backend API health check failed"
fi
echo ""

# Test 2: Analytics Service Health
echo "Test 2: Analytics Service Health Check"
if kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s -f http://localhost:4000/health > /dev/null 2>&1; then
    test_passed "Analytics Service is healthy"
else
    test_failed "Analytics Service health check failed"
fi
echo ""

# Test 3: Create a task (triggers task.created event)
echo "Test 3: Create Task and Verify Event Logging"
TASK_RESPONSE=$(kubectl exec -n $NAMESPACE $API_POD -- curl -s -X POST http://localhost:3000/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Task from Script","completed":false}')

TASK_ID=$(echo $TASK_RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

if [ -n "$TASK_ID" ]; then
    test_passed "Task created with ID: $TASK_ID"
    sleep 2  # Wait for event to be logged
    
    # Verify event in Analytics
    EVENTS=$(kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s http://localhost:4000/analytics/events?limit=5)
    if echo "$EVENTS" | grep -q "task.created"; then
        test_passed "task.created event logged in Analytics"
    else
        test_failed "task.created event not found in Analytics"
    fi
else
    test_failed "Task creation failed"
fi
echo ""

# Test 4: Update task (triggers task.updated event)
echo "Test 4: Update Task and Verify Event"
if [ -n "$TASK_ID" ]; then
    kubectl exec -n $NAMESPACE $API_POD -- curl -s -X PUT http://localhost:3000/api/tasks/$TASK_ID \
        -H "Content-Type: application/json" \
        -d '{"title":"Updated Task","completed":true}' > /dev/null
    
    test_passed "Task $TASK_ID updated"
    sleep 2  # Wait for event
    
    EVENTS=$(kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s http://localhost:4000/analytics/events?limit=5)
    if echo "$EVENTS" | grep -q "task.completed"; then
        test_passed "task.completed event logged in Analytics"
    else
        test_failed "task.completed event not found"
    fi
    
    if echo "$EVENTS" | grep -q "task.updated"; then
        test_passed "task.updated event logged in Analytics"
    else
        test_failed "task.updated event not found"
    fi
fi
echo ""

# Test 5: Analytics Summary
echo "Test 5: Fetch Analytics Summary"
SUMMARY=$(kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s http://localhost:4000/analytics/summary)
if echo "$SUMMARY" | grep -q "totalTasks"; then
    test_passed "Analytics summary retrieved successfully"
    echo "$SUMMARY" | head -10
else
    test_failed "Analytics summary retrieval failed"
fi
echo ""

# Test 6: API Gateway Proxy to Analytics
echo "Test 6: API Gateway Proxy to Analytics Service"
PROXY_RESPONSE=$(kubectl exec -n $NAMESPACE $API_POD -- curl -s http://localhost:3000/api/analytics/summary)
if echo "$PROXY_RESPONSE" | grep -q "totalTasks"; then
    test_passed "API Gateway successfully proxies Analytics requests"
else
    test_failed "API Gateway proxy to Analytics failed"
fi
echo ""

# Test 7: Delete task (triggers task.deleted event)
echo "Test 7: Delete Task and Verify Event"
if [ -n "$TASK_ID" ]; then
    kubectl exec -n $NAMESPACE $API_POD -- curl -s -X DELETE http://localhost:3000/api/tasks/$TASK_ID > /dev/null
    test_passed "Task $TASK_ID deleted"
    sleep 2
    
    EVENTS=$(kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s http://localhost:4000/analytics/events?limit=5)
    if echo "$EVENTS" | grep -q "task.deleted"; then
        test_passed "task.deleted event logged in Analytics"
    else
        test_failed "task.deleted event not found"
    fi
fi
echo ""

# Test 8: Event Count by Type
echo "Test 8: Event Counters by Type"
COUNTERS=$(kubectl exec -n $NAMESPACE $ANALYTICS_POD -- curl -s http://localhost:4000/analytics/tasks/count)
if echo "$COUNTERS" | grep -q "task.created"; then
    test_passed "Event counters retrieved successfully"
    echo "$COUNTERS"
else
    test_failed "Event counters retrieval failed"
fi
echo ""

# Test 9: Database Connectivity
echo "Test 9: Database Connectivity Tests"
# PostgreSQL
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n $NAMESPACE $POSTGRES_POD -- pg_isready -U admin -d tasks_db > /dev/null 2>&1; then
    test_passed "PostgreSQL is accessible"
else
    test_failed "PostgreSQL connectivity issue"
fi

# MongoDB
MONGO_POD=$(kubectl get pod -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n $NAMESPACE $MONGO_POD -- mongosh --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; then
    test_passed "MongoDB is accessible"
else
    test_failed "MongoDB connectivity issue"
fi
echo ""

echo "=========================================="
echo "Test Summary Complete"
echo "=========================================="
echo ""
echo "All microservices communication tests executed."
echo "Check results above for any failures."
echo ""
