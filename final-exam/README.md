# Final Exam - Microservices Architecture with Kubernetes

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Technologies](#technologies)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Monitoring & Observability](#monitoring--observability)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This project demonstrates a complete **microservices architecture** deployed on Kubernetes, featuring:

- **Frontend**: React application with Nginx
- **Backend API Gateway**: Node.js/Express REST API for task management
- **Backend Analytics**: Microservice for event logging and statistics
- **PostgreSQL StatefulSet**: Primary database (3 replicas)
- **MongoDB StatefulSet**: Analytics database (3 replicas)
- **Inter-service Communication**: Synchronous REST API calls
- **High Availability**: HPA, multiple replicas, StatefulSets with persistent storage

### Key Features
✅ Microservices architecture with clear separation of concerns  
✅ Event-driven analytics using REST API communication  
✅ StatefulSets for databases with persistent volumes  
✅ Horizontal Pod Autoscaling (HPA) for dynamic scaling  
✅ Health checks and readiness/liveness probes  
✅ ConfigMaps and Secrets for configuration management  
✅ Nginx reverse proxy for frontend routing  

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Frontend                            │
│                    (React + Nginx)                          │
│                     NodePort: 30090                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ HTTP (Nginx Proxy)
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                   Backend API Gateway                       │
│                  (Node.js + Express)                        │
│                    ClusterIP: 3000                          │
└────┬───────────────────────────────────────────┬────────────┘
     │                                           │
     │ REST API (axios)                         │ REST API
     │                                           │
     │                         ┌─────────────────▼────────────┐
     │                         │   Analytics Microservice     │
     │                         │   (Node.js + Express)        │
     │                         │     ClusterIP: 4000          │
     │                         └─────────┬────────────────────┘
     │                                   │
     │ PostgreSQL Driver                 │ MongoDB Driver
     │                                   │
┌────▼──────────────────────┐  ┌────────▼──────────────────────┐
│   PostgreSQL StatefulSet  │  │    MongoDB StatefulSet        │
│      (3 replicas)         │  │       (3 replicas)            │
│   PVC: 5Gi per replica    │  │   PVC: 5Gi per replica        │
└───────────────────────────┘  └───────────────────────────────┘
```

### Communication Flow

1. **User → Frontend**: User accesses React app via NodePort (30090)
2. **Frontend → Backend API**: Nginx proxies `/api/*` requests to Backend API Gateway
3. **Backend API → PostgreSQL**: CRUD operations on tasks database
4. **Backend API → Analytics**: REST API calls to log events (task.created, task.completed, task.updated, task.deleted)
5. **Analytics → MongoDB**: Stores events and aggregated metrics
6. **Frontend → Analytics** (via API Gateway proxy): Fetches analytics data for dashboard

---

## 🛠️ Technologies

### Frontend
- **React** 18.x
- **Nginx** (Alpine) - Static file serving + reverse proxy

### Backend
- **Node.js** 18 Alpine
- **Express** 4.x - REST API framework
- **axios** 1.6.x - HTTP client for inter-service communication
- **pg** (node-postgres) - PostgreSQL client
- **mongodb** - MongoDB driver
- **cors** - Cross-Origin Resource Sharing

### Databases
- **PostgreSQL** 15 Alpine - Tasks database
- **MongoDB** 7.0 - Analytics/events database

### Infrastructure
- **Kubernetes (K3s)** - Container orchestration
- **Docker** - Containerization
- **StatefulSets** - Stateful workloads with persistent storage
- **HPA** - Horizontal Pod Autoscaler
- **ConfigMaps/Secrets** - Configuration management

---

## 📁 Project Structure

```
final-exam/
├── backend-api/              # API Gateway microservice
│   ├── server.js             # Express server + PostgreSQL + Analytics client
│   ├── package.json          # Dependencies (express, pg, axios, cors)
│   └── Dockerfile            # Node 18 Alpine, port 3000
├── backend-analytics/        # Analytics microservice
│   ├── server.js             # Express server + MongoDB
│   ├── package.json          # Dependencies (express, mongodb, cors)
│   ├── healthcheck.js        # Health probe
│   └── Dockerfile            # Node 18 Alpine, port 4000
├── frontend/                 # React application
│   ├── src/
│   │   ├── App.js            # Main component
│   │   ├── TaskList.js       # Task management UI
│   │   └── index.js          # Entry point
│   ├── public/
│   ├── package.json
│   └── Dockerfile            # Multi-stage: build + nginx
├── k8s/                      # Kubernetes manifests
│   ├── namespace.yaml
│   ├── mongodb-*.yaml        # MongoDB StatefulSet + Services + ConfigMap/Secret
│   ├── postgres-*.yaml       # PostgreSQL StatefulSet + Services + ConfigMap/Secret
│   ├── analytics-*.yaml      # Analytics Deployment + Service + HPA + ConfigMap/Secret
│   ├── backend-api-*.yaml    # Backend API Deployment + Service + HPA + ConfigMap/Secret
│   └── frontend-*.yaml       # Frontend Deployment + Service + HPA + ConfigMap
├── scripts/
│   ├── install.sh            # Deploy all services
│   ├── test-microservices.sh # Test inter-service communication
│   ├── health-check.sh       # Verify all services are healthy
│   └── build-images.sh       # Build and push Docker images
└── README.md
```

---

## ✅ Prerequisites

- **Kubernetes Cluster**: K3s, Minikube, or any K8s cluster
- **kubectl**: Kubernetes CLI
- **Docker**: For building images
- **Docker Hub Account**: For pushing images (or use your own registry)

---

## 🚀 Quick Start

### 1. Build Docker Images

```bash
cd final-exam
./scripts/build-images.sh
```

This will build and push:
- `mohamedessid/final-exam-api:latest`
- `mohamedessid/final-exam-analytics:latest`
- `mohamedessid/final-exam-frontend:latest`

### 2. Deploy to Kubernetes

```bash
./scripts/install.sh
```

This script will:
1. Create `final-exam` namespace
2. Deploy MongoDB StatefulSet (3 replicas)
3. Deploy PostgreSQL StatefulSet (3 replicas)
4. Deploy Analytics microservice (2 replicas + HPA)
5. Deploy Backend API Gateway (2 replicas + HPA)
6. Deploy Frontend (2 replicas + HPA)

### 3. Verify Deployment

```bash
./scripts/health-check.sh
```

### 4. Access the Application

Get the NodePort:
```bash
kubectl get svc frontend-service -n final-exam
```

Access at: `http://<NODE_IP>:30090`

---

## 📖 Deployment Guide

### Step-by-Step Deployment

#### 1. Create Namespace
```bash
kubectl apply -f k8s/namespace.yaml
```

#### 2. Deploy MongoDB
```bash
kubectl apply -f k8s/mongodb-configmap.yaml
kubectl apply -f k8s/mongodb-secret.yaml
kubectl apply -f k8s/mongodb-headless-service.yaml
kubectl apply -f k8s/mongodb-service.yaml
kubectl apply -f k8s/mongodb-statefulset.yaml
```

Wait for pods:
```bash
kubectl wait --for=condition=ready pod -l app=mongodb -n final-exam --timeout=180s
```

#### 3. Deploy PostgreSQL
```bash
kubectl apply -f k8s/postgres-configmap.yaml
kubectl apply -f k8s/postgres-secret.yaml
kubectl apply -f k8s/postgres-headless-service.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-statefulset.yaml
```

#### 4. Deploy Analytics Backend
```bash
kubectl apply -f k8s/analytics-configmap.yaml
kubectl apply -f k8s/analytics-secret.yaml
kubectl apply -f k8s/analytics-service.yaml
kubectl apply -f k8s/analytics-deployment.yaml
kubectl apply -f k8s/analytics-hpa.yaml
```

#### 5. Deploy Backend API Gateway
```bash
kubectl apply -f k8s/backend-api-configmap.yaml
kubectl apply -f k8s/backend-api-secret.yaml
kubectl apply -f k8s/backend-api-service.yaml
kubectl apply -f k8s/backend-api-deployment.yaml
kubectl apply -f k8s/backend-api-hpa.yaml
```

#### 6. Deploy Frontend
```bash
kubectl apply -f k8s/frontend-configmap.yaml
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-hpa.yaml
```

---

## 📚 API Documentation

### Backend API Gateway (Port 3000)

#### Task Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks` | List all tasks |
| POST | `/api/tasks` | Create new task |
| PUT | `/api/tasks/:id` | Update task |
| DELETE | `/api/tasks/:id` | Delete task |
| GET | `/health` | Health check |

#### Analytics Proxy (via API Gateway)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/analytics/summary` | Get global statistics |
| GET | `/api/analytics/tasks/count` | Event counters by type |
| GET | `/api/analytics/events?limit=50` | Recent events |

**Example: Create Task**
```bash
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Complete final exam","completed":false}'
```

### Analytics Service (Port 4000)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/analytics/events` | Log task event |
| GET | `/analytics/summary` | Global statistics |
| GET | `/analytics/tasks/count` | Event counters |
| GET | `/analytics/tasks/timeline?days=7` | Timeline aggregation |
| GET | `/analytics/events?limit=50` | Recent events |
| DELETE | `/analytics/events` | Delete all events (admin) |
| GET | `/health` | Health check |

**Event Types**:
- `task.created`
- `task.completed`
- `task.updated`
- `task.deleted`

**Example: Log Event**
```bash
curl -X POST http://analytics-service:4000/analytics/events \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "task.created",
    "taskId": 123,
    "metadata": {"title": "New task"}
  }'
```

**Example: Get Summary**
```bash
curl http://analytics-service:4000/analytics/summary
```

Response:
```json
{
  "totalTasks": 42,
  "completedTasks": 28,
  "incompleteTasks": 14,
  "completionRate": 66.67,
  "totalEvents": 156,
  "lastUpdated": "2025-01-15T10:30:00.000Z"
}
```

---

## 🧪 Testing

### 1. Health Checks
```bash
./scripts/health-check.sh
```

### 2. Microservices Communication Test
```bash
./scripts/test-microservices.sh
```

This test validates:
- ✅ Backend API health endpoint
- ✅ Analytics Service health endpoint
- ✅ Task creation triggers `task.created` event
- ✅ Task update triggers `task.updated` event
- ✅ Task completion triggers `task.completed` event
- ✅ Task deletion triggers `task.deleted` event
- ✅ Analytics summary retrieval
- ✅ API Gateway proxy to Analytics
- ✅ PostgreSQL connectivity
- ✅ MongoDB connectivity

### 3. Manual Testing

#### Test Event Flow
```bash
# Get API pod
API_POD=$(kubectl get pod -n final-exam -l app=backend-api -o jsonpath='{.items[0].metadata.name}')

# Create task
kubectl exec -n final-exam $API_POD -- curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test task","completed":false}'

# Check analytics events
ANALYTICS_POD=$(kubectl get pod -n final-exam -l app=analytics -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n final-exam $ANALYTICS_POD -- curl http://localhost:4000/analytics/events?limit=10
```

---

## 📊 Monitoring & Observability

### Check Deployment Status
```bash
kubectl get all -n final-exam
```

### View Logs

**Backend API:**
```bash
kubectl logs -f -l app=backend-api -n final-exam
```

**Analytics Service:**
```bash
kubectl logs -f -l app=analytics -n final-exam
```

**Frontend:**
```bash
kubectl logs -f -l app=frontend -n final-exam
```

**MongoDB:**
```bash
kubectl logs -f mongodb-0 -n final-exam
```

**PostgreSQL:**
```bash
kubectl logs -f postgres-0 -n final-exam
```

### Check HPA Status
```bash
kubectl get hpa -n final-exam
```

### Monitor Resources
```bash
kubectl top pods -n final-exam
kubectl top nodes
```

### Check Persistent Volumes
```bash
kubectl get pvc -n final-exam
kubectl get pv
```

---

## 🔧 Troubleshooting

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n final-exam
kubectl describe pod <pod-name> -n final-exam
```

**Check events:**
```bash
kubectl get events -n final-exam --sort-by='.lastTimestamp'
```

### Database Connection Issues

**PostgreSQL:**
```bash
kubectl exec -it postgres-0 -n final-exam -- psql -U admin -d tasks_db
```

**MongoDB:**
```bash
kubectl exec -it mongodb-0 -n final-exam -- mongosh -u admin -p MongoP@ss2025 --authenticationDatabase admin
```

### Analytics Not Receiving Events

**Check Backend API logs:**
```bash
kubectl logs -l app=backend-api -n final-exam | grep -i analytics
```

**Verify ANALYTICS_SERVICE_URL:**
```bash
kubectl get cm backend-api-config -n final-exam -o yaml
```

**Test connectivity:**
```bash
API_POD=$(kubectl get pod -n final-exam -l app=backend-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n final-exam $API_POD -- curl -v http://analytics-service:4000/health
```

### Image Pull Errors

**Check image names:**
```bash
kubectl describe pod <pod-name> -n final-exam | grep -i image
```

**Update deployment with correct image:**
```bash
kubectl set image deployment/backend-api backend-api=mohamedessid/final-exam-api:latest -n final-exam
```

### Clean Up and Redeploy

**Delete namespace (removes all resources):**
```bash
kubectl delete namespace final-exam
```

**Redeploy:**
```bash
./scripts/install.sh
```

---

## 📝 Configuration

### Environment Variables

**Backend API (`backend-api-configmap.yaml`):**
- `PORT`: 3000
- `DB_HOST`: postgres-service
- `DB_PORT`: 5432
- `DB_NAME`: tasks_db
- `DB_USER`: admin (from Secret)
- `DB_PASSWORD`: PostgresP@ss2025 (from Secret)
- `ANALYTICS_SERVICE_URL`: http://analytics-service:4000

**Analytics Service (`analytics-configmap.yaml`):**
- `PORT`: 4000
- `MONGO_URI`: mongodb://mongodb-service:27017
- `MONGO_DB_NAME`: analytics_db
- `MONGO_USER`: admin (from Secret)
- `MONGO_PASSWORD`: MongoP@ss2025 (from Secret)

### Scaling

**Manual scaling:**
```bash
kubectl scale deployment backend-api --replicas=5 -n final-exam
kubectl scale deployment analytics --replicas=3 -n final-exam
```

**HPA automatically scales based on CPU/Memory:**
- Backend API: 2-5 replicas (70% CPU, 80% Memory)
- Analytics: 2-5 replicas (70% CPU, 80% Memory)
- Frontend: 2-4 replicas (70% CPU, 80% Memory)

---

## 🎓 Learning Objectives

This final exam demonstrates:

1. ✅ **Microservices Architecture**: Separation of concerns (API Gateway, Analytics, Frontend)
2. ✅ **Inter-Service Communication**: REST API using axios for synchronous calls
3. ✅ **StatefulSets**: Managing stateful workloads (PostgreSQL, MongoDB) with persistent storage
4. ✅ **ConfigMaps & Secrets**: External configuration management
5. ✅ **High Availability**: Multiple replicas, HPA, health checks
6. ✅ **Event-Driven Design**: Task events logged to Analytics service
7. ✅ **Kubernetes Networking**: ClusterIP, NodePort, DNS service discovery
8. ✅ **Container Best Practices**: Multi-stage builds, health probes, resource limits
9. ✅ **Observability**: Logging, health checks, metrics aggregation

---

## 📞 Support

For questions or issues:
- Check logs: `kubectl logs -l app=<service-name> -n final-exam`
- Run health check: `./scripts/health-check.sh`
- Test microservices: `./scripts/test-microservices.sh`

---

## 🏆 Success Criteria

The deployment is successful when:
- ✅ All pods are in `Running` state
- ✅ All services are `Active`
- ✅ Frontend accessible at NodePort 30090
- ✅ Tasks can be created/updated/deleted
- ✅ Analytics events are logged correctly
- ✅ API Gateway proxies Analytics requests
- ✅ Databases are persistent across pod restarts
- ✅ HPA scales based on load

---

**Author**: Mohamed Essid  
**Date**: 2025  
**Version**: 1.0
