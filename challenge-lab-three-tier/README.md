# Challenge Lab: Three-Tier Application on Kubernetes

## Table des Matières
- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Composants](#composants)
- [Workloads et Justification](#workloads-et-justification)
- [ConfigMaps et Secrets](#configmaps-et-secrets)
- [Best Practices HA](#best-practices-ha)
- [Déploiement](#déploiement)
- [Scénarios de Test](#scénarios-de-test)
- [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

Cette application three-tier démontre une architecture de production complète sur Kubernetes avec :
- **Frontend** : Application React avec Nginx
- **Backend** : API REST Node.js/Express
- **Database** : PostgreSQL StatefulSet avec 3 réplicas

### Objectifs
✅ Implémenter une architecture three-tier complète  
✅ Utiliser les workloads appropriés pour chaque tier  
✅ Configurer ConfigMaps et Secrets pour la configuration  
✅ Appliquer les best practices de Haute Disponibilité  
✅ Tester les scénarios de failover, scaling, et persistence  

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster (K3s)                    │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              Namespace: three-tier-app                     │ │
│  │                                                            │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │         FRONTEND TIER (Stateless)                   │  │ │
│  │  │  ┌──────────────────────────────────────────────┐   │  │ │
│  │  │  │  Deployment: frontend (3 replicas)           │   │  │ │
│  │  │  │  Image: React + Nginx                        │   │  │ │
│  │  │  │  - Anti-affinity (spread across nodes)       │   │  │ │
│  │  │  │  - Liveness/Readiness probes                 │   │  │ │
│  │  │  │  - ConfigMap: API_URL injection              │   │  │ │
│  │  │  └──────────────────────────────────────────────┘   │  │ │
│  │  │           │                                          │  │ │
│  │  │           ▼                                          │  │ │
│  │  │  ┌──────────────────────────────────────────────┐   │  │ │
│  │  │  │  Service: frontend-service (NodePort:30000)  │   │  │ │
│  │  │  └──────────────────────────────────────────────┘   │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  │                         │                                  │ │
│  │                         │ HTTP Requests                    │ │
│  │                         ▼                                  │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │         BACKEND TIER (API Layer)                    │  │ │
│  │  │  ┌──────────────────────────────────────────────┐   │  │ │
│  │  │  │  Deployment: backend (2-5 replicas HPA)      │   │  │ │
│  │  │  │  Image: Node.js + Express API                │   │  │ │
│  │  │  │  - HPA: CPU 70%, Memory 80%                  │   │  │ │
│  │  │  │  - Resource limits: 256Mi/200m               │   │  │ │
│  │  │  │  - ConfigMap: DB connection config           │   │  │ │
│  │  │  │  - Secret: DB credentials                    │   │  │ │
│  │  │  │  - Liveness/Readiness probes (/api/health)   │   │  │ │
│  │  │  └──────────────────────────────────────────────┘   │  │ │
│  │  │           │                                          │  │ │
│  │  │           ▼                                          │  │ │
│  │  │  ┌──────────────────────────────────────────────┐   │  │ │
│  │  │  │  Service: backend-service (NodePort:30001)   │   │  │ │
│  │  │  └──────────────────────────────────────────────┘   │  │ │
│  │  │           │                                          │  │ │
│  │  │  ┌──────────────────────────────────────────────┐   │  │ │
│  │  │  │  HPA: backend-hpa (autoscaling)              │   │  │ │
│  │  │  └──────────────────────────────────────────────┘   │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  │                         │                                  │ │
│  │                         │ PostgreSQL Protocol              │ │
│  │                         ▼                                  │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │         DATABASE TIER (Stateful + HA)               │  │ │
│  │  │  ┌──────────────────────────────────────────────┐   │  │ │
│  │  │  │  StatefulSet: postgres (3 replicas)          │   │  │ │
│  │  │  │  Image: PostgreSQL 15                        │   │  │ │
│  │  │  │                                               │   │  │ │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐│ │
│  │  │  │  │ postgres-0  │  │ postgres-1  │  │ postgres-2  ││ │
│  │  │  │  │  (Primary)  │  │  (Replica)  │  │  (Replica)  ││ │
│  │  │  │  └─────────────┘  └─────────────┘  └─────────────┘│ │
│  │  │  │       │                  │                 │       │ │
│  │  │  │       ▼                  ▼                 ▼       │ │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐│ │
│  │  │  │  │ PVC (5Gi)   │  │ PVC (5Gi)   │  │ PVC (5Gi)   ││ │
│  │  │  │  │ postgres-   │  │ postgres-   │  │ postgres-   ││ │
│  │  │  │  │ storage-0   │  │ storage-1   │  │ storage-2   ││ │
│  │  │  │  └─────────────┘  └─────────────┘  └─────────────┘│ │
│  │  │  │                                               │   │  │ │
│  │  │  │  - volumeClaimTemplates (auto PVC)           │   │  │ │
│  │  │  │  - Liveness/Readiness probes (pg_isready)    │   │  │ │
│  │  │  │  - Resource limits: 512Mi/500m                │   │  │ │
│  │  │  │  - ConfigMap: POSTGRES_DB                     │   │  │ │
│  │  │  │  - Secret: POSTGRES_USER/PASSWORD             │   │  │ │
│  │  │  └──────────────────────────────────────────────┘   │  │ │
│  │  │           │                   │                      │  │ │
│  │  │           ▼                   ▼                      │  │ │
│  │  │  ┌─────────────────┐  ┌─────────────────────────┐   │  │ │
│  │  │  │ postgres-       │  │ postgres-headless       │   │  │ │
│  │  │  │ service         │  │ (ClusterIP: None)       │   │  │ │
│  │  │  │ (ClusterIP)     │  │ DNS: postgres-0.postgres│   │  │ │
│  │  │  │ Load Balancing  │  │      -headless...       │   │  │ │
│  │  │  └─────────────────┘  └─────────────────────────┘   │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘

External Access:
  - Frontend: http://NODE_IP:30000
  - Backend:  http://NODE_IP:30001
```

---

## Composants

### Frontend Tier
- **Technologie** : React 18 + Nginx 1.25
- **Dockerfile** : Multi-stage build (optimize image size)
- **Features** :
  - Task Manager UI
  - API endpoint configuration via ConfigMap
  - Health check endpoint `/health`
  - Production optimizations (gzip, caching, security headers)

### Backend Tier
- **Technologie** : Node.js 18 + Express 4
- **API Endpoints** :
  - `GET /api/health` - Health check
  - `GET /api/tasks` - List all tasks
  - `POST /api/tasks` - Create task
  - `PUT /api/tasks/:id` - Update task
  - `DELETE /api/tasks/:id` - Delete task
- **Features** :
  - PostgreSQL connection pooling
  - Environment-based configuration
  - Graceful shutdown handling

### Database Tier
- **Technologie** : PostgreSQL 15 (Alpine)
- **Schema** :
  ```sql
  CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  ```

---

## Workloads et Justification

| Tier | Workload | Justification |
|------|----------|---------------|
| **Frontend** | **Deployment** | ✅ **Stateless** : Aucune donnée persistante<br>✅ Peut être scalé horizontalement<br>✅ Rolling updates sans interruption<br>✅ Pods interchangeables |
| **Backend** | **Deployment + HPA** | ✅ **Stateless** : API REST sans session<br>✅ Auto-scaling basé sur CPU/Memory<br>✅ Haute disponibilité avec 2-5 réplicas<br>✅ Load balancing automatique |
| **Database** | **StatefulSet** | ✅ **Stateful** : Données persistantes critiques<br>✅ Identité stable (postgres-0, postgres-1, postgres-2)<br>✅ DNS stable par pod<br>✅ Déploiement/suppression ordonnée<br>✅ volumeClaimTemplates (1 PVC par pod)<br>✅ Prêt pour réplication Primary-Replica |

### Pourquoi pas un Deployment pour la Database ?

| Critère | Deployment | StatefulSet |
|---------|-----------|-------------|
| **Nommage pods** | `db-abc123-xyz` (aléatoire) | `postgres-0, postgres-1` (stable) |
| **DNS** | Aléatoire | `postgres-0.postgres-headless...` |
| **Volumes** | 1 PVC partagé | 1 PVC dédié par pod |
| **Ordre démarrage** | Parallèle | Séquentiel (0 → 1 → 2) |
| **Réplication** | ❌ Impossible | ✅ Facile (Primary-Replica) |
| **Use case** | Apps stateless | Bases de données, clusters |

---

## ConfigMaps et Secrets

### ConfigMaps (Configuration non-sensible)

#### 1. `frontend-config`
```yaml
data:
  API_URL: "http://10.174.154.67:30001/api"
  ENVIRONMENT: "production"
```
**Usage** : URL du backend injectée dans l'index.html au démarrage

#### 2. `backend-config`
```yaml
data:
  DB_HOST: "postgres-service"
  DB_PORT: "5432"
  DB_NAME: "taskdb"
  PORT: "5000"
  NODE_ENV: "production"
```
**Usage** : Configuration de connexion PostgreSQL

#### 3. `db-config`
```yaml
data:
  POSTGRES_DB: "taskdb"
```
**Usage** : Nom de la base de données

### Secrets (Données sensibles)

#### `db-secret`
```yaml
data:
  POSTGRES_USER: dGFza3VzZXI=        # taskuser (base64)
  POSTGRES_PASSWORD: U2VjdXJlUEBzczEyMw==  # SecureP@ss123 (base64)
```
**Usage** : Credentials PostgreSQL utilisés par backend et database

### Injection dans les Pods

**Backend Deployment** :
```yaml
env:
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: backend-config
        key: DB_HOST
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: POSTGRES_PASSWORD
```

---

## Best Practices HA (Haute Disponibilité)

### 1. Database Tier (StatefulSet)

| Practice | Implémentation | Bénéfice |
|----------|----------------|----------|
| **Replicas multiples** | `replicas: 3` | Failover automatique si un pod tombe |
| **Persistent Storage** | `volumeClaimTemplates` (5Gi par pod) | Données conservées après restart |
| **Health Checks** | `livenessProbe` + `readinessProbe` (pg_isready) | Détection automatique de pods défaillants |
| **Resource Limits** | `memory: 512Mi, cpu: 500m` | Prévention OOM, scheduling optimal |
| **Stable Network** | Headless service + ClusterIP service | DNS stable + load balancing |
| **Ordered Deployment** | StatefulSet garantit l'ordre 0→1→2 | Pas de race conditions |

### 2. Backend Tier (HPA)

| Practice | Implémentation | Bénéfice |
|----------|----------------|----------|
| **Horizontal Autoscaling** | HPA : 2-5 réplicas | Adaptation automatique à la charge |
| **CPU Threshold** | `averageUtilization: 70%` | Scale up avant saturation |
| **Memory Threshold** | `averageUtilization: 80%` | Prévention OOM |
| **Resource Limits** | `memory: 256Mi, cpu: 200m` | Prévention resource starvation |
| **Health Checks** | Liveness + Readiness (`/api/health`) | Restart automatique si unhealthy |
| **Graceful Shutdown** | SIGTERM handler dans Node.js | Pas de connexions coupées |
| **Rolling Updates** | `maxSurge: 1, maxUnavailable: 0` | Zero-downtime deployments |

### 3. Frontend Tier (Anti-Affinity)

| Practice | Implémentation | Bénéfice |
|----------|----------------|----------|
| **Pod Anti-Affinity** | `preferredDuringSchedulingIgnoredDuringExecution` | Distribution sur différents nœuds |
| **Replicas** | `replicas: 3` | Haute disponibilité |
| **Health Checks** | Liveness + Readiness (`/health`) | Détection pods défaillants |
| **Resource Limits** | `memory: 128Mi, cpu: 100m` | Scheduling efficace |
| **Static Content** | Multi-stage build Nginx | Image légère (~50MB) |

### 4. Network & Service Discovery

| Practice | Implémentation | Bénéfice |
|----------|----------------|----------|
| **ClusterIP Services** | backend-service, postgres-service | Load balancing interne |
| **Headless Service** | postgres-headless | DNS stable par pod |
| **NodePort Services** | frontend:30000, backend:30001 | Accès externe |
| **Service Discovery** | DNS Kubernetes natif | Résolution automatique |

---

## Déploiement

### Prérequis
- Cluster Kubernetes (K3s) fonctionnel
- `kubectl` configuré
- IP du nœud : `10.174.154.67`
- Images Docker buildées et poussées :
  - `mohamedessid/three-tier-frontend:1.0`
  - `mohamedessid/three-tier-backend:1.0`

### Build et Push des Images

```bash
# Frontend
cd frontend
docker build -t mohamedessid/three-tier-frontend:1.0 .
docker push mohamedessid/three-tier-frontend:1.0

# Backend
cd ../backend
docker build -t mohamedessid/three-tier-backend:1.0 .
docker push mohamedessid/three-tier-backend:1.0
```

### Déploiement Complet

```bash
# Rendre le script exécutable
chmod +x scripts/*.sh

# Déployer l'application complète
sudo bash scripts/install.sh
```

**Ordre d'exécution** :
1. Namespace
2. ConfigMaps (db-config, backend-config, frontend-config)
3. Secrets (db-secret)
4. Database (postgres-headless → postgres-statefulset → postgres-service)
5. Backend (backend-deployment → backend-service → backend-hpa)
6. Frontend (frontend-deployment → frontend-service)

### Vérification

```bash
# Santé globale
sudo bash scripts/health-check.sh

# Pods
kubectl get pods -n three-tier-app

# Services
kubectl get svc -n three-tier-app

# PVCs (3 PVCs auto-créés pour PostgreSQL)
kubectl get pvc -n three-tier-app

# HPA
kubectl get hpa -n three-tier-app
```

### Accès

- **Frontend** : http://10.174.154.67:30000
- **Backend API** : http://10.174.154.67:30001/api/health
- **Tasks Endpoint** : http://10.174.154.67:30001/api/tasks

---

## Scénarios de Test

### Exécution de Tous les Tests

```bash
sudo bash scripts/test-scenarios.sh
```

### Test 1: Déploiement Complet ✅

**Objectif** : Vérifier que tous les composants sont déployés

```bash
kubectl get pods -n three-tier-app
kubectl get svc -n three-tier-app
kubectl get pvc -n three-tier-app
```

**Résultat attendu** :
- 3 pods PostgreSQL (postgres-0, postgres-1, postgres-2)
- 2-5 pods Backend (auto-scaling HPA)
- 3 pods Frontend
- 3 PVCs (postgres-storage-postgres-0/1/2)
- Tous les pods en état `Running` et `Ready`

---

### Test 2: Database Failover ✅

**Objectif** : Tester la résilience de PostgreSQL StatefulSet

```bash
# Supprimer le pod postgres-0
kubectl delete pod postgres-0 -n three-tier-app

# Observer la recréation
kubectl get pods -n three-tier-app -l app=postgres -w

# Vérifier après 60s
kubectl get pods -n three-tier-app -l app=postgres
```

**Résultat attendu** :
- Pod `postgres-0` recréé automatiquement avec le **même nom**
- PVC `postgres-storage-postgres-0` réutilisé
- Données persistées (pas de perte)
- Application continue de fonctionner

**Pourquoi ça fonctionne ?**
- StatefulSet garantit le nom stable `postgres-0`
- volumeClaimTemplate réutilise le PVC existant
- Backend reconnecte automatiquement au nouveau pod

---

### Test 3: Backend HPA Scaling ✅

**Objectif** : Tester l'auto-scaling du backend

```bash
# Vérifier HPA actuel
kubectl get hpa -n three-tier-app

# Observer les métriques
kubectl top pods -n three-tier-app -l app=backend

# Générer de la charge (optionnel)
for i in {1..1000}; do
  curl -X POST http://10.174.154.67:30001/api/tasks \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Load test task $i\",\"completed\":false}"
done

# Observer le scaling
kubectl get hpa -n three-tier-app -w
kubectl get pods -n three-tier-app -l app=backend -w
```

**Résultat attendu** :
- HPA scale de 2 à 5 réplicas si CPU > 70% ou Memory > 80%
- Scale down après 60s de stabilisation
- Nouveau pods créés progressivement (maxSurge)

**Configuration HPA** :
- Min: 2 réplicas
- Max: 5 réplicas
- CPU target: 70%
- Memory target: 80%

---

### Test 4: Rolling Update (Zero Downtime) ✅

**Objectif** : Déployer une nouvelle version sans interruption

```bash
# Avant update
kubectl get pods -n three-tier-app -l app=frontend

# Rolling restart (simule un update)
kubectl rollout restart deployment/frontend -n three-tier-app

# Observer le rollout
kubectl rollout status deployment/frontend -n three-tier-app

# Pendant le rollout
while true; do
  curl -s http://10.174.154.67:30000 > /dev/null
  echo "$(date) - Frontend accessible"
  sleep 1
done
```

**Résultat attendu** :
- Pods remplacés progressivement (1 par 1)
- Application **toujours accessible** (zero downtime)
- Aucune erreur 503 pendant le rollout

**Stratégie** :
- `maxUnavailable: 1` : Max 1 pod down à la fois
- `maxSurge: 1` : Max 1 pod extra pendant update
- Readiness probe assure que nouveau pod est prêt avant suppression ancien

---

### Test 5: Data Persistence ✅

**Objectif** : Vérifier la persistance des données après restart

```bash
# 1. Créer une tâche de test
curl -X POST http://10.174.154.67:30001/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Persistence Test Task","completed":false}'

# 2. Récupérer toutes les tâches (noter l'ID)
curl -s http://10.174.154.67:30001/api/tasks | jq .

# 3. Supprimer le pod PostgreSQL
kubectl delete pod postgres-0 -n three-tier-app

# 4. Attendre recréation (60s)
kubectl wait --for=condition=ready pod/postgres-0 -n three-tier-app --timeout=120s

# 5. Vérifier que les données existent toujours
curl -s http://10.174.154.67:30001/api/tasks | jq .
```

**Résultat attendu** :
- Tâche "Persistence Test Task" toujours présente après restart
- Aucune perte de données
- PVC `postgres-storage-postgres-0` réutilisé

**Comment ça fonctionne ?**
- PVC survit à la suppression du pod
- StatefulSet remonte le même PVC sur nouveau pod
- PostgreSQL retrouve ses données dans `/var/lib/postgresql/data`

---

### Test 6: Service Discovery ✅

**Objectif** : Tester la résolution DNS entre services

```bash
# Identifier un pod backend
BACKEND_POD=$(kubectl get pod -n three-tier-app -l app=backend -o jsonpath='{.items[0].metadata.name}')

# Résoudre le service ClusterIP
kubectl exec -n three-tier-app ${BACKEND_POD} -- nslookup postgres-service.three-tier-app.svc.cluster.local

# Résoudre le headless service (DNS stable)
kubectl exec -n three-tier-app ${BACKEND_POD} -- nslookup postgres-0.postgres-headless.three-tier-app.svc.cluster.local
kubectl exec -n three-tier-app ${BACKEND_POD} -- nslookup postgres-1.postgres-headless.three-tier-app.svc.cluster.local
```

**Résultat attendu** :
- `postgres-service` résout vers une IP ClusterIP (load balancing)
- `postgres-0.postgres-headless` résout vers l'IP directe du pod postgres-0
- Backend peut se connecter via `postgres-service:5432`

---

### Test 7: Load Balancing ✅

**Objectif** : Vérifier la distribution du trafic

```bash
# Frontend load balancing (10 requêtes)
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://10.174.154.67:30000 | grep -o "frontend-[a-z0-9-]*" | head -1
  sleep 0.5
done

# Backend load balancing (vérifier logs)
for i in {1..10}; do
  curl -s http://10.174.154.67:30001/api/health > /dev/null
  echo "Request $i sent"
done

# Vérifier les logs de tous les pods backend
kubectl logs -n three-tier-app -l app=backend --tail=20
```

**Résultat attendu** :
- Requêtes distribuées entre les 3 pods frontend
- Requêtes distribuées entre les 2-5 pods backend
- Service Kubernetes fait du round-robin par défaut

---

### Test 8: Network Policies (Optionnel)

**Objectif** : Isoler les tiers avec des Network Policies

```bash
# Appliquer network policies
kubectl apply -f k8s/network-policies.yaml

# Tester depuis frontend vers backend (devrait fonctionner)
FRONTEND_POD=$(kubectl get pod -n three-tier-app -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n three-tier-app ${FRONTEND_POD} -- curl -s http://backend-service:5000/api/health

# Tester depuis frontend vers database (devrait être bloqué)
kubectl exec -n three-tier-app ${FRONTEND_POD} -- nc -zv postgres-service 5432
```

---

## Troubleshooting

### Pods ne démarrent pas

```bash
# Vérifier les events
kubectl describe pod <POD_NAME> -n three-tier-app

# Logs détaillés
kubectl logs <POD_NAME> -n three-tier-app

# Erreurs communes
# - ImagePullBackOff : Image Docker n'existe pas sur Docker Hub
# - CrashLoopBackOff : Application crash au démarrage (vérifier logs)
# - Pending : Ressources insuffisantes (CPU/Memory)
```

### Backend ne peut pas se connecter à la DB

```bash
# Vérifier les credentials
kubectl get secret db-secret -n three-tier-app -o yaml
echo "dGFza3VzZXI=" | base64 -d  # Devrait afficher "taskuser"

# Tester la connexion depuis backend pod
BACKEND_POD=$(kubectl get pod -n three-tier-app -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n three-tier-app ${BACKEND_POD} -- nc -zv postgres-service 5432

# Vérifier les logs PostgreSQL
kubectl logs postgres-0 -n three-tier-app
```

### Frontend n'affiche pas les données

```bash
# Vérifier l'injection de l'API_URL
kubectl get cm frontend-config -n three-tier-app -o yaml

# Vérifier les logs Nginx
FRONTEND_POD=$(kubectl get pod -n three-tier-app -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl logs ${FRONTEND_POD} -n three-tier-app

# Tester backend depuis navigateur
curl http://10.174.154.67:30001/api/health
```

### HPA ne scale pas

```bash
# Vérifier metrics-server installé
kubectl get deployment metrics-server -n kube-system

# Vérifier les métriques disponibles
kubectl top pods -n three-tier-app

# Si pas de métriques, installer metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### PVC reste en Pending

```bash
# Vérifier les PVCs
kubectl get pvc -n three-tier-app

# Vérifier la StorageClass
kubectl get sc

# K3s utilise "local-path" par défaut
# Si absent, installer : https://github.com/rancher/local-path-provisioner
```

---

## Résumé des Best Practices Implémentées

✅ **Workload approprié** : Deployment (stateless), StatefulSet (stateful)  
✅ **ConfigMaps/Secrets** : Séparation config non-sensible / sensible  
✅ **Haute Disponibilité** :  
  - Database: 3 réplicas + volumeClaimTemplates + probes  
  - Backend: HPA 2-5 réplicas + resource limits  
  - Frontend: 3 réplicas + anti-affinity  
✅ **Health Checks** : Liveness + Readiness probes sur tous les pods  
✅ **Auto-Scaling** : HPA avec CPU et Memory targets  
✅ **Persistence** : volumeClaimTemplates (15Gi total)  
✅ **Service Discovery** : ClusterIP + Headless services  
✅ **Zero Downtime** : Rolling updates avec maxSurge/maxUnavailable  
✅ **Monitoring** : Health endpoints + pod metrics  
✅ **Security** : Secrets base64, resource limits, probes  

---

## Auteur

**Mohamed Essid**  
Docker Hub: `mohamedessid`  
GitHub: `Admiralphp/CloudContainerOrchestration`  

---

## Licence

Ce projet est à but éducatif dans le cadre du Master DevOps 2025.
