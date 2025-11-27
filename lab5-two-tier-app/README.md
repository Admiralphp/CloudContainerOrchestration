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

1. IP du nœud K3s : `10.174.154.128`
2. Accéder à : `http://10.174.154.128:30080/`
3. Remplir le formulaire (nom, email) et valider.
4. Vérifier que les données apparaissent dans la table des enregistrements.

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

## 7. Points à mentionner dans le compte rendu

- Description de l'architecture deux-tiers (web + DB).
- Justification de l'usage de NodePort pour exposer l'application.
- Justification de ClusterIP pour la base de données (accès interne uniquement).
- Explication de l'utilisation des variables d'environnement dans les manifests YAML.

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
curl http://10.174.154.128:30080/

# Consulter les logs
kubectl logs -n lab5-app deployment/web-deployment
kubectl logs -n lab5-app deployment/db-deployment
```
