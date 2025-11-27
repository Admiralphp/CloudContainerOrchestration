# Screenshots du LAB 5

Ce dossier contient les captures d'écran démontrant le bon fonctionnement de l'application two-tier.

## Liste des Screenshots Requis

1. **01-cluster-nodes.png** - Vérification du cluster K3s
2. **02-deployed-resources.png** - Toutes les ressources déployées
3. **03-pods-status.png** - État des pods
4. **04-web-logs.png** - Logs de l'application web
5. **05-db-logs.png** - Logs de la base de données
6. **06-web-interface-empty.png** - Interface web au démarrage
7. **07-form-filled.png** - Formulaire rempli
8. **08-data-inserted.png** - Données insérées avec succès
9. **09-multiple-records.png** - Plusieurs enregistrements
10. **10-db-verification.png** - Vérification directe dans MySQL

## Comment Capturer les Screenshots

### Screenshots Terminal (Linux/Mac)
```bash
# Prendre une capture d'écran du terminal
scrot screenshot.png
```

### Screenshots Terminal (Windows)
- Utiliser l'outil Capture d'écran Windows (Win + Shift + S)
- Ou PowerShell : `Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait("{PRTSC}")`

### Screenshots Navigateur
- Utiliser les DevTools du navigateur (F12)
- Ou extension de capture d'écran
- Ou simplement Ctrl + Shift + S (Firefox) / Ctrl + Shift + P "screenshot" (Chrome)

## Commandes pour Générer les Screenshots

### 1. Cluster Nodes
```bash
kubectl get nodes
# Capturer : 01-cluster-nodes.png
```

### 2. Ressources Déployées
```bash
kubectl get all -n lab5-app
# Capturer : 02-deployed-resources.png
```

### 3. Status des Pods
```bash
kubectl get pods -n lab5-app -o wide
# Capturer : 03-pods-status.png
```

### 4. Logs Web
```bash
kubectl logs -n lab5-app deployment/web-deployment --tail=20
# Capturer : 04-web-logs.png
```

### 5. Logs Database
```bash
kubectl logs -n lab5-app deployment/db-deployment --tail=20
# Capturer : 05-db-logs.png
```

### 6-9. Interface Web
```
http://10.174.154.128:30085/
```
- 06 : Page vide
- 07 : Formulaire rempli
- 08 : Après insertion
- 09 : Plusieurs enregistrements

### 10. Vérification DB
```bash
kubectl exec -it -n lab5-app deployment/db-deployment -- mysql -uappuser -papppassword -e "SELECT * FROM appdb.people;"
# Capturer : 10-db-verification.png
```

---

**Note** : Nommer les fichiers exactement comme indiqué pour faciliter la référence dans la documentation.
