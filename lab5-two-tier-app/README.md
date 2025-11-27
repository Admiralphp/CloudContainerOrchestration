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
│   ├── web-deployment.yaml
│   ├── web-service.yaml
│   ├── db-deployment.yaml
│   └── db-service.yaml
├── scripts/
│   └── install.sh
├── docs/
│   └── architecture.png
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

## 8. Validation et Preuves de Succès

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
kubectl logs -n lab5-app deployment/db-deployment
```
