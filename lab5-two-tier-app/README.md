# Lab 5 - Two Tier Application sur K3s

## 1. Présentation du projet

Ce projet implémente une application web simple (formulaire nom / email)
connectée à une base de données MySQL. L'objectif est de déployer une
architecture deux-tiers sur un cluster K3s avec deux Deployments et deux Services
(NodePort pour le web, ClusterIP pour la base de données).

## 2. Architecture

- Frontend : Flask (Python), exposé via un Service de type NodePort
- Backend : MySQL (image officielle), exposé via un Service de type ClusterIP
- Les paramètres de connexion (host, user, password, database) sont fournis
  sous forme de variables d'environnement directement dans les manifests YAML.

Le schéma ci-dessous illustre l'architecture (fichier `docs/architecture.png`) :

Client (navigateur) → Service Web (NodePort 30080) → Pods Flask
Pods Flask → Service DB (ClusterIP 3306) → Pod MySQL

## 3. Prérequis

- Cluster K3s fonctionnel (kubectl configuré)
- Docker (pour builder et pousser l'image)
- Accès à un registre d'images (ex: Docker Hub)
- Nom d'image utilisé : `mohamedessid/lab5-web:1.0`

## 4. Étapes de déploiement

```bash
# Build + push + déploiement
./scripts/install.sh

# Vérification des ressources
kubectl get all -n lab5-app
```

## 5. Test de l'application

1. IP du nœud K3s : `10.174.154.67`
2. Accéder à : `http://10.174.154.67:30085/`
3. Remplir le formulaire (nom, email) et valider.
4. Vérifier que les données apparaissent dans la table des enregistrements.

### 📸 Captures d'écran de validation

Toutes les captures d'écran sont disponibles dans le dossier [`docs/screenshots/`](docs/screenshots/).

**Déploiement et Configuration :**
- [Installation complète](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/install-sh.png)
- [Cluster K3s opérationnel](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/01-cluster-nodes.png)
- [Ressources déployées](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/02-deployed-resources.png)
- [Status des pods](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/03-pods-status.png)
- [Logs application web](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/04-web-logs.png)
- [Logs base de données](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/05-db-logs.png)

**Tests Fonctionnels :**
- [Interface web vide](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/06-web-interface-empty.png)
- [Formulaire rempli](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/07-form-filled.png)
- [Données insérées](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/08-data-inserted.png)
- [Plusieurs enregistrements](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/09-multiple-records.png)
- [Vérification base de données](https://github.com/Admiralphp/CloudContainerOrchestration/blob/main/lab5-two-tier-app/docs/screenshots/10-db-verification.png)

## 6. Structure du projet

```text
lab5-two-tier-app/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
│       └── index.html
├── k8s/
│   ├── namespace.yaml
│   ├── db-configmap.yaml      # STEP 2: Configuration non sensible
│   ├── web-configmap.yaml     # STEP 2: Configuration non sensible
│   ├── db-secret.yaml         # STEP 2: Credentials sécurisés
│   ├── db-pv.yaml             # STEP 3: Persistent Volume
│   ├── db-pvc.yaml            # STEP 3: Persistent Volume Claim
│   ├── web-deployment.yaml
│   ├── web-service.yaml
│   ├── db-deployment.yaml     # STEP 3: Monte le PVC
│   └── db-service.yaml
├── scripts/
│   └── install.sh
├── docs/
│   ├── architecture.png
│   ├── screenshots/
│   └── VALIDATION.md
├── Dockerfile
├── README.md
└── .gitignore
```

## 7. Analyse Technique et Justifications

### 7.1 Architecture Deux-Tiers

Ce projet implémente une architecture deux-tiers classique séparant :

**Frontend (Web Tier)** :
- Application Flask (Python 3.12) avec interface web HTML
- 2 réplicas pour assurer la haute disponibilité
- Conteneurisée via Docker et déployée sur Kubernetes
- Communique avec la base de données via variables d'environnement

**Backend (Data Tier)** :
- Base de données MySQL 8.0 (image officielle)
- 1 replica (suffisant pour un environnement de lab)
- Service ClusterIP pour isolation réseau
- Configuration déclarative des credentials et de la base de données

Cette séparation permet :
- **Scalabilité** : Possibilité d'augmenter les réplicas web indépendamment
- **Maintenabilité** : Mise à jour du frontend sans toucher à la base de données
- **Sécurité** : Isolation de la couche données derrière un service interne

### 7.2 Choix de NodePort pour l'Exposition Web

**Décision** : Service de type `NodePort` sur le port 30085

**Justifications** :
1. **Environnement K3s** : K3s est souvent déployé sur des infrastructures locales ou edge où les LoadBalancers cloud (AWS ELB, Azure LB) ne sont pas disponibles
2. **Simplicité** : NodePort permet un accès direct via `<IP_NODE>:30085` sans configuration supplémentaire
3. **Démo et Tests** : Idéal pour des environnements de développement et de laboratoire
4. **Pas de dépendances externes** : Fonctionne immédiatement sans MetalLB ou autre solution de LoadBalancing

**Alternative écartée** : LoadBalancer aurait nécessité une infrastructure cloud ou l'installation de MetalLB.

### 7.3 Choix de ClusterIP pour la Base de Données

**Décision** : Service de type `ClusterIP` pour MySQL

**Justifications** :
1. **Principe de sécurité** : La base de données ne doit JAMAIS être exposée publiquement
2. **Accès restreint** : Seuls les pods du cluster peuvent communiquer avec le service `db-service`
3. **Réduction de la surface d'attaque** : Prévient les accès non autorisés depuis l'extérieur
4. **Best Practice** : Configuration standard pour les backends de données dans Kubernetes

**Bénéfices** :
- Protection contre les attaques externes
- Communication interne rapide via le réseau overlay de Kubernetes
- Découverte de service automatique via DNS interne (`db-service.lab5-app.svc.cluster.local`)

### 7.4 Gestion de la Configuration via Variables d'Environnement

**Approche** : Variables définies directement dans les manifests YAML (deployment)

**Paramètres Web App** :
```yaml
- name: DB_HOST
  value: "db-service"
- name: DB_PORT
  value: "3306"
- name: DB_USER
  value: "appuser"
- name: DB_PASSWORD
  value: "apppassword"
- name: DB_NAME
  value: "appdb"
```

**Paramètres MySQL** :
```yaml
- name: MYSQL_ROOT_PASSWORD
  value: "rootpassword"
- name: MYSQL_DATABASE
  value: "appdb"
- name: MYSQL_USER
  value: "appuser"
- name: MYSQL_PASSWORD
  value: "apppassword"
```

**Justifications pour ce LAB** :
1. **Simplicité pédagogique** : Facilite la compréhension des débutants
2. **Visibilité** : Toute la configuration est visible dans un seul fichier
3. **Conformité au LAB** : L'énoncé spécifie explicitement "pas de ConfigMaps ni Secrets"
4. **Débogage facile** : Modification rapide pour tests et validation

**Évolution future recommandée** :
- Production : Utiliser des **Secrets** Kubernetes pour les mots de passe
- Centralisation : Migrer vers des **ConfigMaps** pour les paramètres non sensibles
- Sécurité renforcée : Intégration avec **HashiCorp Vault** ou **Azure Key Vault**

### 7.5 Namespace Dédié

**Décision** : Déploiement dans le namespace `lab5-app`

**Avantages** :
- **Isolation logique** : Séparation des ressources du LAB 5 des autres projets
- **Gestion simplifiée** : `kubectl delete namespace lab5-app` supprime tout proprement
- **Organisation** : Facilite la visualisation avec `kubectl get all -n lab5-app`
- **Quotas potentiels** : Possibilité d'appliquer des ResourceQuotas par namespace

---

## STEP 2 : ConfigMaps et Secrets pour Amélioration de la Sécurité

### 8.1 Objectif

Améliorer la configuration et la sécurité en introduisant :
- **ConfigMaps** : Pour les paramètres de configuration non sensibles
- **Secrets** : Pour les credentials et mots de passe

### 8.2 ConfigMaps Créés

#### `db-configmap.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  namespace: lab5-app
data:
  MYSQL_DATABASE: "appdb"
```

**Utilisation** : Stocke le nom de la base de données (non sensible)

#### `web-configmap.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: lab5-app
data:
  DB_HOST: "db-service"
  DB_PORT: "3306"
  DB_NAME: "appdb"
```

**Utilisation** : Stocke les paramètres de connexion (host, port, nom de DB)

### 8.3 Secret Créé

#### `db-secret.yaml`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: lab5-app
type: Opaque
data:
  MYSQL_ROOT_PASSWORD: cm9vdHBhc3N3b3Jk    # rootpassword (base64)
  MYSQL_USER: YXBwdXNlcg==                 # appuser (base64)
  MYSQL_PASSWORD: YXBwcGFzc3dvcmQ=         # apppassword (base64)
  DB_PASSWORD: YXBwcGFzc3dvcmQ=            # apppassword (base64)
  DB_USER: YXBwdXNlcg==                    # appuser (base64)
```

**Note** : Les valeurs sont encodées en base64 pour la sécurité.

### 8.4 Modification des Deployments

#### Dans `db-deployment.yaml` :
```yaml
env:
  - name: MYSQL_ROOT_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: MYSQL_ROOT_PASSWORD
  - name: MYSQL_DATABASE
    valueFrom:
      configMapKeyRef:
        name: db-config
        key: MYSQL_DATABASE
  - name: MYSQL_USER
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: MYSQL_USER
  - name: MYSQL_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: MYSQL_PASSWORD
```

#### Dans `web-deployment.yaml` :
```yaml
env:
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: web-config
        key: DB_HOST
  - name: DB_PORT
    valueFrom:
      configMapKeyRef:
        name: web-config
        key: DB_PORT
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: DB_USER
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: DB_PASSWORD
  - name: DB_NAME
    valueFrom:
      configMapKeyRef:
        name: web-config
        key: DB_NAME
```

### 8.5 Avantages de cette Approche

#### Sécurité Améliorée
- **Secrets encodés** : Les mots de passe ne sont plus en clair dans les YAML
- **RBAC possible** : Contrôle d'accès granulaire aux Secrets
- **Chiffrement au repos** : Les Secrets peuvent être chiffrés dans etcd

#### Gestion Centralisée
- **Single Source of Truth** : Une seule ConfigMap/Secret pour plusieurs deployments
- **Mise à jour facilitée** : Modification centralisée sans redéployer les pods
- **Réutilisabilité** : Partage de configuration entre plusieurs applications

#### Séparation des Responsabilités
- **DevOps** : Gère les ConfigMaps (configuration applicative)
- **SecOps** : Gère les Secrets (credentials sensibles)
- **Développeurs** : Se concentrent sur le code, pas sur la configuration

#### Environnements Multiples
- ConfigMaps/Secrets différents par environnement (dev, staging, prod)
- Même code de déploiement, configuration adaptée
- Facilite le CI/CD

### 8.6 Commandes de Déploiement STEP 2

```bash
# 1. Créer le namespace
kubectl apply -f k8s/namespace.yaml

# 2. Créer les ConfigMaps
kubectl apply -n lab5-app -f k8s/db-configmap.yaml
kubectl apply -n lab5-app -f k8s/web-configmap.yaml

# 3. Créer les Secrets
kubectl apply -n lab5-app -f k8s/db-secret.yaml

# 4. Déployer les applications
kubectl apply -n lab5-app -f k8s/db-deployment.yaml
kubectl apply -n lab5-app -f k8s/db-service.yaml
kubectl apply -n lab5-app -f k8s/web-deployment.yaml
kubectl apply -n lab5-app -f k8s/web-service.yaml

# 5. Vérifier les ConfigMaps et Secrets
kubectl get configmaps -n lab5-app
kubectl get secrets -n lab5-app
kubectl describe configmap web-config -n lab5-app
kubectl describe secret db-secret -n lab5-app
```

### 8.7 Vérification de la Configuration

```bash
# Voir les variables d'environnement d'un pod web
kubectl exec -n lab5-app deployment/web-deployment -- env | grep DB

# Voir les variables d'environnement du pod MySQL
kubectl exec -n lab5-app deployment/db-deployment -- env | grep MYSQL
```

### 8.8 Génération des Valeurs Base64 pour Secrets

Si vous devez changer les mots de passe, utilisez :

```bash
# Linux/Mac
echo -n "nouveaumotdepasse" | base64

# Windows PowerShell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("nouveaumotdepasse"))
```

### 8.9 Rotation des Secrets

Pour mettre à jour un mot de passe :

```bash
# 1. Éditer le Secret
kubectl edit secret db-secret -n lab5-app

# 2. Redémarrer les pods pour charger le nouveau Secret
kubectl rollout restart deployment/web-deployment -n lab5-app
kubectl rollout restart deployment/db-deployment -n lab5-app
```

---

## STEP 3 : Persistent Volumes (PV) et Persistent Volume Claims (PVC)

### 9.1 Objectif

Assurer la **persistance des données** de la base de données MySQL même en cas de :
- Redémarrage des pods
- Suppression accidentelle du deployment
- Migration vers un autre nœud du cluster

Sans PV/PVC, les données MySQL sont perdues à chaque redémarrage du pod car elles sont stockées dans le système de fichiers éphémère du conteneur.

### 9.2 Architecture de Stockage

```
┌─────────────────────────────────────────┐
│           MySQL Pod                     │
│  ┌───────────────────────────────────┐  │
│  │  Container: mysql:8.0             │  │
│  │  Volume Mount: /var/lib/mysql     │  │
│  └──────────────┬────────────────────┘  │
│                 │                        │
│                 ▼                        │
│  ┌───────────────────────────────────┐  │
│  │  Volume: mysql-storage            │  │
│  │  Source: PVC (mysql-pvc)          │  │
│  └──────────────┬────────────────────┘  │
└─────────────────┼────────────────────────┘
                  │
                  ▼
   ┌─────────────────────────────────┐
   │  PersistentVolumeClaim          │
   │  Name: mysql-pvc                │
   │  Request: 1Gi                   │
   │  StorageClass: local-path       │
   └──────────────┬──────────────────┘
                  │
                  ▼
   ┌─────────────────────────────────┐
   │  PersistentVolume               │
   │  Name: mysql-pv                 │
   │  Capacity: 2Gi                  │
   │  Path: /data/mysql (host)       │
   └─────────────────────────────────┘
```

### 9.3 Persistent Volume (PV)

#### `db-pv.yaml`
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
  namespace: lab5-app
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  hostPath:
    path: /data/mysql
    type: DirectoryOrCreate
```

**Caractéristiques** :
- **Capacité** : 2Gi (supérieur au PVC pour avoir de la marge)
- **Access Mode** : `ReadWriteOnce` (un seul nœud peut monter en lecture/écriture)
- **Reclaim Policy** : `Retain` (les données sont conservées après suppression du PVC)
- **StorageClass** : `local-path` (compatible K3s par défaut)
- **HostPath** : `/data/mysql` sur le nœud K3s

### 9.4 Persistent Volume Claim (PVC)

#### `db-pvc.yaml`
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: lab5-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

**Utilisation** :
- **Demande** : 1Gi de stockage
- **Binding** : Kubernetes lie automatiquement ce PVC au PV `mysql-pv`
- **Namespace** : `lab5-app` (doit correspondre au deployment)

### 9.5 Modification du Deployment MySQL

#### Ajout dans `db-deployment.yaml` :
```yaml
spec:
  template:
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          volumeMounts:
            - name: mysql-storage
              mountPath: /var/lib/mysql    # Répertoire de données MySQL
      volumes:
        - name: mysql-storage
          persistentVolumeClaim:
            claimName: mysql-pvc            # Référence au PVC
```

**Explication** :
- **volumeMounts** : Monte le volume dans le conteneur à `/var/lib/mysql`
- **volumes** : Définit le volume comme source le PVC `mysql-pvc`
- MySQL stocke ses bases de données, tables et logs dans `/var/lib/mysql`

### 9.6 Avantages de la Persistance

#### 1. **Durabilité des Données**
- Les données survivent aux redémarrages de pods
- Protection contre les suppressions accidentelles
- Backup facilité (sauvegarde du volume)

#### 2. **Haute Disponibilité**
- Migration de pod vers un autre nœud sans perte de données (avec stockage réseau)
- Résilience face aux pannes matérielles

#### 3. **Scalabilité**
- Possibilité d'augmenter la taille du volume
- Changement de StorageClass sans refaire le deployment

#### 4. **Séparation du Stockage**
- Cycle de vie indépendant : PV/PVC vs Deployment
- Plusieurs deployments peuvent utiliser le même PVC (selon AccessMode)

#### 5. **Production Ready**
- Conforme aux best practices Kubernetes
- Compatible avec tous les cloud providers (AWS EBS, Azure Disk, GCP PD)

### 9.7 Types d'Access Modes

| Access Mode | Description | Cas d'usage |
|-------------|-------------|-------------|
| **ReadWriteOnce (RWO)** | Lecture/écriture par un seul nœud | MySQL, PostgreSQL (1 replica) |
| **ReadOnlyMany (ROX)** | Lecture seule par plusieurs nœuds | Assets statiques, configurations |
| **ReadWriteMany (RWX)** | Lecture/écriture par plusieurs nœuds | NFS, applications distribuées |

**Notre choix** : `ReadWriteOnce` car MySQL ne supporte pas l'écriture concurrente.

### 9.8 StorageClass dans K3s

K3s inclut par défaut le provisioner **local-path** :

```bash
# Vérifier les StorageClasses disponibles
kubectl get storageclass

# Résultat attendu :
# NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      AGE
# local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   10d
```

**local-path** :
- Stockage sur le système de fichiers local du nœud
- Idéal pour environnements de développement et K3s
- Pour production cloud : utiliser AWS EBS, Azure Disk, etc.

### 9.9 Commandes de Déploiement STEP 3

```bash
# 1. Créer le Persistent Volume
kubectl apply -f k8s/db-pv.yaml

# 2. Créer le Persistent Volume Claim
kubectl apply -n lab5-app -f k8s/db-pvc.yaml

# 3. Vérifier le binding PV ↔ PVC
kubectl get pv
kubectl get pvc -n lab5-app

# 4. Déployer la base de données avec persistance
kubectl apply -n lab5-app -f k8s/db-deployment.yaml

# 5. Vérifier le montage du volume
kubectl describe pod -n lab5-app -l app=db
```

### 9.10 Vérification de la Persistance

#### Test de persistance des données :

```bash
# 1. Insérer des données dans l'application web
# Via http://10.174.154.67:30085/

# 2. Vérifier les données dans MySQL
kubectl exec -n lab5-app deployment/db-deployment -- \
  mysql -uappuser -papppassword -e "SELECT * FROM appdb.people;"

# 3. Supprimer le pod MySQL (simulation de crash)
kubectl delete pod -n lab5-app -l app=db

# 4. Attendre que le pod redémarre
kubectl wait --for=condition=ready pod -l app=db -n lab5-app --timeout=60s

# 5. Vérifier que les données sont toujours présentes
kubectl exec -n lab5-app deployment/db-deployment -- \
  mysql -uappuser -papppassword -e "SELECT * FROM appdb.people;"

# ✅ Les données doivent être intactes !
```

### 9.11 Gestion du Volume

#### Voir la taille utilisée :
```bash
# Sur le nœud K3s
sudo du -sh /data/mysql
```

#### Nettoyer les données (attention : irréversible) :
```bash
# Supprimer le PVC (libère le volume)
kubectl delete pvc mysql-pvc -n lab5-app

# Supprimer le PV
kubectl delete pv mysql-pv

# Supprimer les données sur le nœud
sudo rm -rf /data/mysql
```

#### Augmenter la taille du PVC :
```bash
# Éditer le PVC
kubectl edit pvc mysql-pvc -n lab5-app

# Modifier spec.resources.requests.storage
# Exemple: 1Gi → 5Gi
```

### 9.12 Reclaim Policies

| Policy | Comportement | Usage |
|--------|--------------|-------|
| **Retain** | Données conservées après suppression PVC | Production (sauvegarde manuelle) |
| **Delete** | Données supprimées avec le PVC | Développement |
| **Recycle** | Volume réinitialisé et réutilisable | Déprécié |

**Notre choix** : `Retain` pour éviter les pertes de données accidentelles.

### 9.13 Backup des Données

```bash
# Backup MySQL vers un fichier
kubectl exec -n lab5-app deployment/db-deployment -- \
  mysqldump -uroot -prootpassword --all-databases > backup.sql

# Ou copier le volume directement
sudo tar -czf mysql-backup-$(date +%Y%m%d).tar.gz -C /data/mysql .
```

### 9.14 Limitations de HostPath

⚠️ **HostPath** (local-path) a des limitations :

1. **Pas de haute disponibilité** : Les données sont liées à un nœud spécifique
2. **Migration impossible** : Si le pod change de nœud, le volume n'est pas accessible
3. **Pas de réplication** : Un seul point de défaillance

**Pour production multi-nœuds**, utiliser :
- **NFS** : Stockage réseau partagé
- **Ceph/Rook** : Stockage distribué
- **Cloud Storage** : AWS EBS, Azure Disk, GCP PD

---

## 10. Validation et Preuves de Succès

Consultez le document `docs/VALIDATION.md` pour :
- La checklist complète de conformité avec l'énoncé du LAB
- Les instructions détaillées pour capturer les screenshots requis
- Les commandes de vérification à exécuter
- La liste des 10 screenshots à fournir dans `docs/screenshots/`

### Commandes de Validation Rapide

```bash
# Vérifier que tous les pods sont Running
kubectl get pods -n lab5-app

# Vérifier les services
kubectl get svc -n lab5-app

# Tester l'accès web
curl http://10.174.154.67:30085/

# Consulter les logs
kubectl logs -n lab5-app deployment/web-deployment
kubectl logs -n lab5-app statefulset/postgres
```

---

## LAB 8 : Migration vers StatefulSet pour PostgreSQL

### 11.1 Pourquoi Migrer vers StatefulSet ?

#### Limitations des Deployments pour les Bases de Données

Dans les LABs précédents (5-7), nous utilisions un **Deployment** pour MySQL/PostgreSQL. Cette approche fonctionne mais présente plusieurs limitations :

| Problème | Impact | Exemple |
|----------|--------|---------|
| **Noms de pods aléatoires** | `db-deployment-7f8d9-xyz12` change à chaque restart | Impossible de cibler un pod spécifique |
| **Pas d'identité réseau stable** | Connexion impossible à une instance précise | Réplication master-slave impossible |
| **Gestion manuelle des volumes** | Création manuelle PV/PVC requise | Erreurs humaines, complexité |
| **Pas d'ordre de démarrage** | Pods démarrent/s'arrêtent aléatoirement | Problèmes de synchronisation |
| **Scaling difficile** | Pas de coordination entre réplicas | Corruption de données possible |
| **Pas de réplication** | Configuration master-slave impossible | Pas de haute disponibilité |

#### Avantages des StatefulSets

StatefulSet est **spécifiquement conçu** pour les applications stateful (bases de données, systèmes distribués, clusters) :

| Fonctionnalité | Description | Bénéfice |
|----------------|-------------|----------|
| **Identité stable** | `postgres-0`, `postgres-1`, `postgres-2` | Noms prévisibles et constants |
| **DNS stable** | `postgres-0.postgres-headless.lab5-app.svc.cluster.local` | Adressage direct d'un pod |
| **Déploiement ordonné** | Séquentiel : 0 → 1 → 2 | Garantit l'ordre d'initialisation |
| **Suppression ordonnée** | Inverse : 2 → 1 → 0 | Graceful shutdown propre |
| **Volume automatique** | `volumeClaimTemplates` crée PVC par pod | Pas de gestion manuelle |
| **Storage persistant** | Chaque pod a son volume dédié | Données conservées |
| **HA Ready** | Facilite master-slave, clustering | Production-ready |

### 11.2 Migration de MySQL vers PostgreSQL

Nous migrons également de **MySQL vers PostgreSQL** pour des raisons de :
- **Performance** : Meilleur pour les applications complexes
- **Standards** : Meilleur support SQL standard
- **Réplication** : Streaming replication native plus robuste
- **Extensions** : PostGIS, pg_stat_statements, etc.

### 11.3 Architecture LAB 8

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Namespace: lab5-app                            │ │
│  │                                                         │ │
│  │  ┌──────────────────┐      ┌─────────────────────┐   │ │
│  │  │  Web Deployment  │      │  StatefulSet        │   │ │
│  │  │  (2 replicas)    │──────│  postgres           │   │ │
│  │  │                  │      │                      │   │ │
│  │  │  web-xxx-pod1    │      │  ┌───────────────┐  │   │ │
│  │  │  web-xxx-pod2    │      │  │  postgres-0   │  │   │ │
│  │  └──────────────────┘      │  │  (primary)    │  │   │ │
│  │           │                 │  └───────────────┘  │   │ │
│  │           │                 │         │           │   │ │
│  │           │                 │         ▼           │   │ │
│  │           │                 │  ┌───────────────┐  │   │ │
│  │           │                 │  │     PVC       │  │   │ │
│  │           │                 │  │ postgres-     │  │   │ │
│  │           │                 │  │ storage-      │  │   │ │
│  │           │                 │  │ postgres-0    │  │   │ │
│  │           │                 │  │    (5Gi)      │  │   │ │
│  │           │                 │  └───────────────┘  │   │ │
│  │           │                 └─────────────────────┘   │ │
│  │           │                                           │ │
│  │           ▼                          ▼                │ │
│  │  ┌──────────────┐         ┌─────────────────┐       │ │
│  │  │ web-service  │         │   db-service    │       │ │
│  │  │ NodePort     │         │   ClusterIP     │       │ │
│  │  │ :30085       │         │   :5432         │       │ │
│  │  └──────────────┘         └─────────────────┘       │ │
│  │                                    │                  │ │
│  │                           ┌────────────────┐         │ │
│  │                           │ postgres-      │         │ │
│  │                           │ headless       │         │ │
│  │                           │ (DNS stable)   │         │ │
│  │                           └────────────────┘         │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘

Client Browser ──> NodePort :30085 ──> Web Pods ──> db-service ──> postgres-0
                                                         │
                        Headless Service: postgres-0.postgres-headless...
```

### 11.4 Fichiers Créés/Modifiés

#### Nouveaux fichiers :
- `k8s/postgres-statefulset.yaml` - StatefulSet avec volumeClaimTemplates
- `k8s/postgres-headless-service.yaml` - Headless service (DNS stable)
- `k8s/postgres-service.yaml` - Service normal (load balancing)
- `scripts/test-statefulset.sh` - Script de test complet

#### Fichiers supprimés :
- ~~`k8s/db-pv.yaml`~~ - Plus nécessaire (auto-provisioning)
- ~~`k8s/db-pvc.yaml`~~ - Plus nécessaire (volumeClaimTemplates)
- ~~`k8s/db-deployment.yaml`~~ - Remplacé par StatefulSet

#### Fichiers modifiés :
- `k8s/db-configmap.yaml` - POSTGRES_DB au lieu de MYSQL_DATABASE
- `k8s/db-secret.yaml` - POSTGRES_USER/PASSWORD au lieu de MYSQL
- `k8s/web-configmap.yaml` - Connexion PostgreSQL
- `scripts/install.sh` - Ordre de déploiement adapté

### 11.5 StatefulSet PostgreSQL

#### `postgres-statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: lab5-app
spec:
  serviceName: "postgres-headless"    # Référence au headless service
  replicas: 1                         # Peut scaler à 2-3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          ports:
            - containerPort: 5432
              name: postgres
          env:
            - name: POSTGRES_DB
              valueFrom:
                configMapKeyRef:
                  name: db-config
                  key: POSTGRES_DB
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: POSTGRES_PASSWORD
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:               # Auto-création PVC
    - metadata:
        name: postgres-storage
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: "local-path"
        resources:
          requests:
            storage: 5Gi
```

**Points clés** :
- `serviceName`: Lien vers le headless service
- `volumeClaimTemplates`: Crée automatiquement `postgres-storage-postgres-0`
- `PGDATA`: Sous-répertoire pour éviter conflits de permissions

### 11.6 Headless Service

#### `postgres-headless-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: lab5-app
spec:
  clusterIP: None                    # Headless !
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
      name: postgres
```

**Rôle** : Fournit un DNS stable pour chaque pod :
- `postgres-0.postgres-headless.lab5-app.svc.cluster.local`
- `postgres-1.postgres-headless.lab5-app.svc.cluster.local`

### 11.7 Service Normal

#### `postgres-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: lab5-app
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

**Rôle** : Load-balancing pour les applications (web app)

### 11.8 volumeClaimTemplates Expliqué

`volumeClaimTemplates` est la fonctionnalité clé des StatefulSets :

#### Comment ça fonctionne :

1. **Création automatique** : Pour chaque replica, Kubernetes crée un PVC
   ```
   Replica 0 → postgres-storage-postgres-0 (5Gi)
   Replica 1 → postgres-storage-postgres-1 (5Gi)
   Replica 2 → postgres-storage-postgres-2 (5Gi)
   ```

2. **Binding automatique** : Chaque PVC est lié au pod correspondant
   ```
   postgres-0 → monte postgres-storage-postgres-0
   postgres-1 → monte postgres-storage-postgres-1
   ```

3. **Persistance** : PVC survit même si :
   - Pod est supprimé
   - StatefulSet est supprimé
   - Réplicas est réduit (scale down)

4. **Réutilisation** : Si on scale up, les anciens PVC sont réutilisés
   ```bash
   kubectl scale statefulset postgres --replicas=0  # postgres-1 supprimé
   kubectl scale statefulset postgres --replicas=2  # postgres-1 recréé avec même PVC
   ```

#### Avantages vs PV/PVC manuels :

| Aspect | PV/PVC Manuel (LAB 5-7) | volumeClaimTemplates (LAB 8) |
|--------|-------------------------|------------------------------|
| Création | Manuelle (2 fichiers) | Automatique |
| Scaling | 1 PVC partagé | 1 PVC par pod |
| Gestion | Erreurs possibles | Zéro configuration |
| Nettoyage | Manuel | Automatique mais retenu |

### 11.9 Procédure de Déploiement LAB 8

```bash
# 1. Nettoyer l'ancien déploiement (si LAB 5-7 existe)
kubectl delete namespace lab5-app

# 2. Déployer avec le script mis à jour
cd ~/CloudContainerOrchestration/lab5-two-tier-app
sudo ./scripts/install.sh

# 3. Vérifier le StatefulSet
kubectl get statefulset -n lab5-app
kubectl get pods -n lab5-app -l app=postgres

# 4. Vérifier les PVCs auto-créés
kubectl get pvc -n lab5-app

# 5. Tester les DNS stables
kubectl run -n lab5-app dns-test --image=busybox:1.28 --rm -it -- \
  nslookup postgres-0.postgres-headless.lab5-app.svc.cluster.local

# 6. Exécuter les tests complets
sudo bash scripts/test-statefulset.sh
```

### 11.10 Tests de Validation

Le script `test-statefulset.sh` effectue 7 tests :

#### Test 1 : Nommage Prévisible
```bash
kubectl get pods -n lab5-app -l app=postgres
# Résultat : postgres-0 (pas de suffixe aléatoire)
```

#### Test 2 : DNS Stable
```bash
nslookup postgres-0.postgres-headless.lab5-app.svc.cluster.local
# Résultat : Adresse IP du pod postgres-0
```

#### Test 3 : PVC Automatique
```bash
kubectl get pvc -n lab5-app
# Résultat : postgres-storage-postgres-0 créé automatiquement
```

#### Test 4 : Persistance des Données
```bash
# Insérer données
kubectl exec postgres-0 -- psql -U appuser -d appdb -c \
  "CREATE TABLE test (id INT, data VARCHAR(50));"
  
# Supprimer pod
kubectl delete pod postgres-0 -n lab5-app

# Vérifier après restart
kubectl exec postgres-0 -- psql -U appuser -d appdb -c \
  "SELECT * FROM test;"
# ✓ Données toujours présentes
```

#### Test 5 : Identité Stable
```bash
# Après suppression, même nom
kubectl get pod postgres-0 -n lab5-app
# AGE récent mais nom identique
```

#### Test 6 : Scaling Séquentiel
```bash
kubectl scale statefulset postgres --replicas=3 -n lab5-app

# Ordre de création : postgres-0 → postgres-1 → postgres-2
# postgres-1 attend que postgres-0 soit Ready
```

#### Test 7 : Headless vs Regular Service
```bash
kubectl get svc -n lab5-app
# postgres-headless : ClusterIP None
# db-service : ClusterIP assignée
```

### 11.11 Scaling du StatefulSet

#### Scale Up (1 → 3 replicas)

```bash
# Augmenter à 3 réplicas
kubectl scale statefulset postgres --replicas=3 -n lab5-app

# Observer la création séquentielle
kubectl get pods -n lab5-app -l app=postgres -w

# Résultat :
# postgres-0 : Running
# postgres-1 : PodInitializing (attend postgres-0)
# postgres-2 : Pending (attend postgres-1)

# Vérifier les PVCs créés
kubectl get pvc -n lab5-app
# postgres-storage-postgres-0 (5Gi)
# postgres-storage-postgres-1 (5Gi)
# postgres-storage-postgres-2 (5Gi)
```

#### Scale Down (3 → 1 replica)

```bash
# Réduire à 1 replica
kubectl scale statefulset postgres --replicas=1 -n lab5-app

# Ordre de suppression : postgres-2 → postgres-1
kubectl get pods -n lab5-app -l app=postgres -w

# ⚠️ Les PVCs sont CONSERVÉS
kubectl get pvc -n lab5-app
# postgres-storage-postgres-1 : Bound (mais non utilisé)
# postgres-storage-postgres-2 : Bound (mais non utilisé)
```

**Note** : PVCs retenues permettent de rescaler sans perte de données.

### 11.12 Configuration Réplication (Avancé)

Pour configurer PostgreSQL en mode Primary-Replica (futur LAB) :

```yaml
# postgres-0 = Primary (lecture/écriture)
# postgres-1, postgres-2 = Replicas (lecture seule)

env:
  - name: POSTGRES_REPLICA_MODE
    value: "slave"
  - name: POSTGRES_MASTER_SERVICE
    value: "postgres-0.postgres-headless"
```

### 11.13 Rollback vers Deployment

Si nécessaire, pour revenir au Deployment :

```bash
# 1. Sauvegarder les données
kubectl exec postgres-0 -n lab5-app -- pg_dump -U appuser appdb > backup.sql

# 2. Supprimer StatefulSet
kubectl delete statefulset postgres -n lab5-app

# 3. Recréer Deployment
kubectl apply -f k8s/db-deployment-backup.yaml

# 4. Restaurer les données
kubectl exec db-deployment-xxx -n lab5-app -- psql -U appuser appdb < backup.sql
```

### 11.14 Comparaison Deployment vs StatefulSet

| Critère | Deployment | StatefulSet |
|---------|-----------|-------------|
| **Noms pods** | `db-xxx-random` | `postgres-0, postgres-1` |
| **DNS** | Aléatoire | Stable par pod |
| **Volume** | 1 PVC partagé | 1 PVC par pod |
| **Ordre** | Aléatoire | Séquentiel |
| **Scaling** | Parallèle | Ordonné |
| **Use case** | Apps stateless | Bases de données, clusters |
| **Réplication** | ❌ Impossible | ✅ Possible |
| **HA** | ❌ Difficile | ✅ Facile |

### 11.15 Résumé des Améliorations LAB 8

✅ **Migration MySQL → PostgreSQL** : Meilleure performance et réplication  
✅ **Deployment → StatefulSet** : Identité et ordre garantis  
✅ **volumeClaimTemplates** : Auto-provisioning des PVCs  
✅ **Headless Service** : DNS stable par pod  
✅ **Ready pour HA** : Base pour réplication master-slave  
✅ **Scripts de test** : Validation automatisée  
✅ **Production-ready** : Suit les best practices Kubernetes

---

## 12. Accès et Validation Finale
