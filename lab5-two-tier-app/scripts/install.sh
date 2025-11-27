#!/usr/bin/env bash
set -e

IMAGE_NAME="mohamedessid/lab5-web:1.0"

echo "[1/4] Build de l'image Docker..."
sudo docker build -t "$IMAGE_NAME" .

echo "[2/4] Push de l'image vers le registre..."
sudo docker push "$IMAGE_NAME"

echo "[3/4] Vérification de K3s..."
if ! sudo systemctl is-active --quiet k3s; then
    echo "K3s n'est pas actif, démarrage..."
    sudo systemctl start k3s
    sleep 10
fi

echo "[4/7] Création du namespace..."
kubectl apply -f k8s/namespace.yaml --validate=false

echo "[5/7] Déploiement des ConfigMaps..."
kubectl apply -n lab5-app -f k8s/db-configmap.yaml --validate=false
kubectl apply -n lab5-app -f k8s/web-configmap.yaml --validate=false

echo "[6/9] Déploiement des Secrets..."
kubectl apply -n lab5-app -f k8s/db-secret.yaml --validate=false

echo "[7/9] Déploiement du Headless Service (pour StatefulSet)..."
kubectl apply -n lab5-app -f k8s/postgres-headless-service.yaml --validate=false

echo "[8/9] Déploiement du StatefulSet PostgreSQL..."
kubectl apply -n lab5-app -f k8s/postgres-statefulset.yaml --validate=false

echo "Attente du StatefulSet postgres-0..."
kubectl wait --for=condition=ready pod/postgres-0 -n lab5-app --timeout=120s

echo "[9/9] Déploiement des Services et Web App..."
kubectl apply -n lab5-app -f k8s/postgres-service.yaml --validate=false
kubectl apply -n lab5-app -f k8s/web-deployment.yaml --validate=false
kubectl apply -n lab5-app -f k8s/web-service.yaml --validate=false

echo "Déploiement terminé."
echo ""
echo "=== StatefulSet Information ==="
kubectl get statefulset -n lab5-app
echo ""
echo "=== Pods ==="
kubectl get pods -n lab5-app -l app=postgres
echo ""
echo "=== PVCs (auto-created) ==="
kubectl get pvc -n lab5-app
echo ""
echo "=== Services ==="
kubectl get svc -n lab5-app
echo ""
echo "Accès web: http://10.174.154.67:30085/"
