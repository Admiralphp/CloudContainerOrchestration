# Guide de Déploiement - Coexistence Challenge Lab & Final Exam

## 🎯 Objectif

Déployer **Challenge Lab** et **Final Exam** sur la **même VM K3s** sans conflits.

---

## ✅ Analyse des Conflits Potentiels

### 1. Namespaces (Pas de conflit)
- ✅ **Challenge Lab**: `three-tier-app`
- ✅ **Final Exam**: `final-exam`
- **Isolation garantie** par Kubernetes

### 2. NodePorts (Pas de conflit)
- ✅ **Challenge Lab**: Port `30080`
- ✅ **Final Exam**: Port `30090`
- **Ports différents** - pas de collision

### 3. Ressources VM (⚠️ Conflit possible)

#### Storage (PVCs)
| Application | PVCs | Taille totale |
|------------|------|---------------|
| Challenge Lab | 6 (PostgreSQL 3 replicas × 2) | ~30 Gi |
| Final Exam (Full) | 12 (PostgreSQL 3×2 + MongoDB 3×2) | ~60 Gi |
| **TOTAL** | **18** | **~90 Gi** |

#### CPU/Memory
| Application | Pods | CPU min | Memory min |
|------------|------|---------|------------|
| Challenge Lab | 6-8 | ~1.5 vCPU | ~2 GB |
| Final Exam (Full) | 10-14 | ~2.5 vCPU | ~3 GB |
| **TOTAL** | **16-22** | **~4 vCPU** | **~5-6 GB** |

---

## 🔍 Étape 1: Vérifier les Ressources de la VM

### Option A: Sur votre machine locale
```bash
# SSH vers la VM
ssh mohamed@10.174.154.67

# Exécuter le script de vérification
cd final-exam
chmod +x scripts/check-vm-resources.sh
./scripts/check-vm-resources.sh
```

### Option B: Commandes manuelles sur la VM
```bash
# Vérifier CPU et mémoire
kubectl top nodes
free -h
lscpu | grep "CPU(s)"

# Vérifier storage disponible
df -h /var/lib/rancher/k3s

# Vérifier déploiements existants
kubectl get all --all-namespaces
kubectl get pvc --all-namespaces
```

### Critères de Décision

| Ressource VM | Déploiement Recommandé |
|--------------|------------------------|
| **CPU: 4+ cores, RAM: 8+ GB, Storage: 100+ Gi** | ✅ **Scénario 1**: Les deux apps en full mode |
| **CPU: 2-3 cores, RAM: 4-6 GB, Storage: 50-80 Gi** | ⚠️ **Scénario 2**: Final Exam en mode minimal |
| **CPU: 2 cores, RAM: 4 GB, Storage: <50 Gi** | 🚨 **Scénario 3**: Une seule app à la fois |

---

## 📦 Scénario 1: VM Puissante (Recommandé)

### Conditions
- ✅ CPU: 4+ cores
- ✅ RAM: 8+ GB
- ✅ Storage: 100+ Gi disponibles

### Déploiement
```bash
# Challenge Lab déjà déployé sur namespace three-tier-app
# Accessible sur http://10.174.154.67:30080

# Déployer Final Exam en mode complet
cd final-exam
./scripts/install.sh

# Vérifier les deux applications
kubectl get pods -n three-tier-app
kubectl get pods -n final-exam

# Accès
# Challenge Lab: http://10.174.154.67:30080
# Final Exam:    http://10.174.154.67:30090
```

### Avantages
- ✅ Haute disponibilité (3 replicas DB)
- ✅ Les deux apps indépendantes
- ✅ Démonstration complète

---

## ⚙️ Scénario 2: VM Moyenne (Mode Minimal)

### Conditions
- ⚠️ CPU: 2-3 cores
- ⚠️ RAM: 4-6 GB
- ⚠️ Storage: 50-80 Gi

### Déploiement avec Réduction
```bash
# Challenge Lab reste en mode complet (déjà déployé)

# Déployer Final Exam avec 1 replica par DB
cd final-exam
./scripts/install-minimal.sh

# Ce script réduit automatiquement:
# - MongoDB: 3 replicas → 1 replica
# - PostgreSQL: 3 replicas → 1 replica
# - Économie: 50 Gi storage, ~40% CPU/RAM
```

### Comparaison

| Ressource | Mode Full | Mode Minimal | Économie |
|-----------|-----------|--------------|----------|
| PVCs Final Exam | 12 | 2 | -10 PVCs |
| Storage Final Exam | 60 Gi | 10 Gi | -50 Gi |
| Pods Final Exam | 10-14 | 6-8 | -40% |

### Avantages
- ✅ Les deux apps fonctionnelles
- ✅ Ressources partagées efficacement
- ⚠️ Final Exam sans HA (acceptable pour démo)

---

## 🔄 Scénario 3: VM Limitée (Déploiement Séquentiel)

### Conditions
- 🚨 CPU: 2 cores
- 🚨 RAM: 4 GB
- 🚨 Storage: <50 Gi

### Option A: Supprimer Challenge Lab puis déployer Final Exam
```bash
# Sauvegarder les screenshots du Challenge Lab
# Puis supprimer
kubectl delete namespace three-tier-app

# Libère:
# - 6 PVCs × 5Gi = 30 Gi
# - 6-8 pods
# - ~1.5 vCPU, ~2 GB RAM

# Déployer Final Exam
cd final-exam
./scripts/install.sh

# Accès: http://10.174.154.67:30090
```

### Option B: Garder Challenge Lab, déployer Final Exam temporairement
```bash
# Déployer Final Exam en mode minimal
cd final-exam
./scripts/install-minimal.sh

# Tester et prendre screenshots

# Supprimer Final Exam
kubectl delete namespace final-exam

# Challenge Lab reste accessible sur 30080
```

---

## 🧪 Tests de Coexistence

### 1. Vérifier les deux applications
```bash
# Challenge Lab
curl http://10.174.154.67:30080
kubectl get pods -n three-tier-app

# Final Exam
curl http://10.174.154.67:30090
kubectl get pods -n final-exam
```

### 2. Tester l'isolation des namespaces
```bash
# Les services sont isolés
kubectl get svc -n three-tier-app
kubectl get svc -n final-exam

# Les PVCs sont séparés
kubectl get pvc -n three-tier-app
kubectl get pvc -n final-exam
```

### 3. Vérifier les ressources
```bash
# État global
kubectl get all --all-namespaces
kubectl top nodes
kubectl top pods --all-namespaces
```

### 4. Test de charge (optionnel)
```bash
# Challenge Lab
ab -n 100 -c 5 http://10.174.154.67:30080/

# Final Exam
ab -n 100 -c 5 http://10.174.154.67:30090/

# Vérifier HPA scaling
watch kubectl get hpa --all-namespaces
```

---

## 📸 Plan de Capture Screenshots

### Challenge Lab (30080)
1. Frontend - Liste de tâches
2. kubectl get all -n three-tier-app
3. kubectl get pvc -n three-tier-app
4. HPA status

### Final Exam (30090)
1. Frontend - Liste de tâches
2. Analytics Dashboard (après implémentation)
3. kubectl get all -n final-exam
4. kubectl get pvc -n final-exam
5. Test microservices output
6. Logs montrant communication inter-services

### Coexistence
1. `kubectl get all --all-namespaces`
2. `kubectl top nodes`
3. Both apps accessible (split screen browser)

---

## 🆘 Troubleshooting

### Problème: Pods en Pending
```bash
# Vérifier les événements
kubectl get events -n final-exam --sort-by='.lastTimestamp'

# Cause probable: Storage ou CPU insuffisant
kubectl describe pod <pod-name> -n final-exam

# Solution: Mode minimal ou suppression Challenge Lab
./scripts/install-minimal.sh
```

### Problème: PVC Pending
```bash
# Vérifier PVCs
kubectl get pvc --all-namespaces

# Vérifier storage disponible sur VM
df -h /var/lib/rancher/k3s

# Si plein: Supprimer une application
kubectl delete namespace three-tier-app
```

### Problème: OOMKilled (Out of Memory)
```bash
# Identifier le pod
kubectl get pods -n final-exam | grep OOMKilled

# Réduire les replicas
kubectl scale deployment backend-api --replicas=1 -n final-exam
kubectl scale deployment analytics --replicas=1 -n final-exam
```

---

## 🎯 Recommandation Finale

### Pour une Démo Complète
1. **Vérifier ressources VM**: `./scripts/check-vm-resources.sh`
2. **Si ressources OK (4+ vCPU, 8+ GB)**: Déployer les deux en full mode
3. **Si ressources limitées**: Final Exam en mode minimal
4. **Si très limité**: Déployer séquentiellement (prendre screenshots puis cleanup)

### Ordre de Déploiement Optimal
```bash
# 1. Challenge Lab (déjà fait)
# 2. Vérifier ressources
ssh mohamed@10.174.154.67
cd final-exam
./scripts/check-vm-resources.sh

# 3a. Si ressources OK
./scripts/install.sh

# 3b. Si ressources limitées
./scripts/install-minimal.sh

# 4. Tests
./scripts/health-check.sh
./scripts/test-microservices.sh

# 5. Screenshots des deux apps

# 6. Cleanup optionnel après démo
kubectl delete namespace final-exam
# Ou
kubectl delete namespace three-tier-app
```

---

## 📊 Matrice de Décision Rapide

| VM Specs | Action | Challenge Lab | Final Exam | Total Pods |
|----------|--------|---------------|------------|------------|
| 4+ vCPU, 8+ GB, 100+ Gi | ✅ Les deux full | 3 replicas | 3 replicas | 16-22 |
| 2-3 vCPU, 4-6 GB, 50-80 Gi | ⚠️ Final minimal | 3 replicas | 1 replica | 12-16 |
| 2 vCPU, 4 GB, <50 Gi | 🚨 Séquentiel | OU | OU | 6-10 |

---

**Conclusion**: Les deux applications **peuvent coexister** sur la même VM grâce à:
- ✅ Namespaces séparés
- ✅ NodePorts différents (30080 vs 30090)
- ✅ Mode minimal si ressources limitées
- ✅ Scripts de vérification et déploiement flexibles
