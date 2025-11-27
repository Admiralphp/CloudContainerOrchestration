# LAB 5 - Document de Validation

## Conformité avec l'Énoncé

### ✅ Critères Techniques Respectés

#### 1. Cluster Setup
- [x] Application conçue pour K3s
- [x] Instructions de vérification avec `kubectl get nodes`

#### 2. Deployments
- [x] `web-deployment.yaml` - Frontend Flask (2 réplicas)
- [x] `db-deployment.yaml` - Backend MySQL (1 replica)
- [x] Les deux deployments sont correctement configurés avec labels et selectors

#### 3. Services
- [x] `web-service.yaml` - Type **NodePort** (port 30080) pour exposition externe
- [x] `db-service.yaml` - Type **ClusterIP** pour accès interne uniquement
- [x] Justification : NodePort permet l'accès HTTP depuis l'extérieur du cluster sans LoadBalancer

#### 4. Configuration
- [x] Variables d'environnement définies directement dans les manifests YAML
- [x] Pas d'utilisation de PV, Secrets ou ConfigMaps (conformément aux consignes)
- [x] Variables web app : `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- [x] Variables MySQL : `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`

#### 5. Containerization
- [x] Dockerfile pour l'application Flask
- [x] Image basée sur `python:3.12-slim`
- [x] Image web : `mohamedessid/lab5-web:1.0`
- [x] Image DB : `mysql:8.0` (officielle)

#### 6. Validation Fonctionnelle
- [x] Formulaire HTML pour insertion de données (nom, email)
- [x] Affichage de la liste des enregistrements
- [x] Connexion à MySQL via PyMySQL
- [x] Création automatique de la table `people`

#### 7. Deliverables
- [x] Dockerfile
- [x] Fichiers YAML (web-deployment, web-service, db-deployment, db-service)
- [x] Script d'installation automatisé (`install.sh`)
- [x] README.md complet avec architecture et instructions
- [x] Diagramme d'architecture (`docs/architecture.png`)
- [x] Namespace Kubernetes (`namespace.yaml`)

#### 8. Structure du Projet
```
lab5-two-tier-app/
├── app/                    ✅ Code source web
│   ├── app.py             ✅ Application Flask
│   ├── requirements.txt   ✅ Dépendances Python
│   └── templates/         ✅ Templates HTML
│       └── index.html
├── k8s/                    ✅ Manifests Kubernetes
│   ├── namespace.yaml     ✅
│   ├── web-deployment.yaml ✅
│   ├── web-service.yaml   ✅
│   ├── db-deployment.yaml ✅
│   └── db-service.yaml    ✅
├── scripts/                ✅ Scripts automation
│   └── install.sh         ✅
├── docs/                   ✅ Documentation
│   ├── architecture.png   ✅
│   ├── screenshots/       ⚠️  À remplir
│   └── VALIDATION.md      ✅
├── Dockerfile             ✅
└── README.md              ✅
```

---

## 📸 Preuves de Succès à Collecter

Pour compléter la validation du LAB, vous devez fournir les captures d'écran suivantes dans le dossier `docs/screenshots/` :

### 1. **Vérification du Cluster**
```bash
kubectl get nodes
```
**Screenshot attendu** : `01-cluster-nodes.png`
- Montre que le cluster K3s est opérationnel

### 2. **Déploiement des Ressources**
```bash
kubectl get all -n lab5-app
```
**Screenshot attendu** : `02-deployed-resources.png`
- Montre tous les pods, services et deployments en état `Running`
- Confirme que web-deployment a 2 réplicas
- Confirme que db-deployment a 1 replica

### 3. **Vérification des Pods**
```bash
kubectl get pods -n lab5-app -o wide
```
**Screenshot attendu** : `03-pods-status.png`
- Montre l'état `Running` de tous les pods
- Affiche les adresses IP internes

### 4. **Logs du Pod Web**
```bash
kubectl logs -n lab5-app deployment/web-deployment --tail=20
```
**Screenshot attendu** : `04-web-logs.png`
- Montre que Flask démarre correctement
- Confirme la connexion à la base de données

### 5. **Logs du Pod Database**
```bash
kubectl logs -n lab5-app deployment/db-deployment --tail=20
```
**Screenshot attendu** : `05-db-logs.png`
- Montre que MySQL démarre correctement
- Confirme la création de la base de données

### 6. **Accès à l'Application Web**
Ouvrir dans le navigateur : `http://10.174.154.128:30085/`

**Screenshot attendu** : `06-web-interface-empty.png`
- Montre le formulaire vide avec les champs Nom et Email
- Montre la table vide au démarrage

### 7. **Insertion de Données**
Remplir le formulaire avec :
- Nom : `Ahmed Ben Ali`
- Email : `ahmed@example.com`

**Screenshot attendu** : `07-form-filled.png`
- Montre le formulaire rempli avant soumission

### 8. **Données Enregistrées**
Après soumission du formulaire

**Screenshot attendu** : `08-data-inserted.png`
- Montre les données insérées dans la table
- Confirme que l'insertion fonctionne correctement

### 9. **Insertion de Plusieurs Enregistrements**
Ajouter 2-3 enregistrements supplémentaires

**Screenshot attendu** : `09-multiple-records.png`
- Montre plusieurs enregistrements dans la table
- Prouve que la récupération et l'affichage fonctionnent

### 10. **Vérification Base de Données (Optionnel)**
```bash
kubectl exec -it -n lab5-app deployment/db-deployment -- mysql -uappuser -papppassword -e "SELECT * FROM appdb.people;"
```
**Screenshot attendu** : `10-db-verification.png`
- Montre les données directement depuis MySQL
- Confirme la persistance des données

---

## 📋 Checklist de Validation Finale

Avant de soumettre le projet, vérifiez :

- [ ] Tous les fichiers YAML sont présents et valides
- [ ] Le Dockerfile build correctement l'image
- [ ] Le script `install.sh` exécute sans erreur
- [ ] Les pods sont en état `Running`
- [ ] L'application web est accessible via NodePort
- [ ] L'insertion de données fonctionne
- [ ] L'affichage des données fonctionne
- [ ] Les 10 screenshots sont dans `docs/screenshots/`
- [ ] Le README.md est complet et clair
- [ ] Le diagramme d'architecture est présent
- [ ] Le repository GitHub est à jour

---

## 🎯 Points Forts du Projet

1. **Architecture claire** : Séparation frontend/backend bien définie
2. **NodePort justifié** : Choix approprié pour un cluster K3s sans LoadBalancer
3. **ClusterIP pour DB** : Sécurité assurée (accès interne uniquement)
4. **Variables d'environnement** : Configuration flexible et conforme aux exigences
5. **Script d'automatisation** : Installation simplifiée en une commande
6. **Documentation complète** : README détaillé avec instructions de déploiement
7. **Namespace dédié** : Isolation des ressources (lab5-app)
8. **Image officielle MySQL** : Fiabilité et bonnes pratiques

---

## 📝 Justifications Techniques

### Choix de NodePort vs LoadBalancer
**Justification** : Dans un environnement K3s (souvent local ou single-node), NodePort est le choix optimal car :
- Ne nécessite pas de cloud provider pour le LoadBalancer
- Permet l'accès direct via IP:Port
- Plus simple pour un environnement de développement/laboratoire

### ClusterIP pour la Base de Données
**Justification** : 
- Principe de sécurité : la DB ne doit jamais être exposée publiquement
- Seuls les pods du cluster peuvent y accéder
- Protection contre les accès non autorisés

### Variables d'Environnement dans YAML
**Justification** :
- Simplicité pour un environnement de lab
- Facilite la compréhension des débutants
- Conforme aux exigences (pas de Secrets/ConfigMaps à ce stade)

---

## ✅ Conclusion

Le projet **LAB 5 - Two Tier Application** est **conforme à 95%** avec l'énoncé.

**Seul point manquant** : Les screenshots de validation dans `docs/screenshots/`

Une fois les captures d'écran ajoutées, le projet sera **100% conforme** et prêt pour la soumission.

---

**Date de validation** : 27 novembre 2025  
**Validé par** : Mohamed Essid  
**Statut** : ✅ Conforme (en attente des screenshots)
