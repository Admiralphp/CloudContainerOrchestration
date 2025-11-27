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

echo "[7/9] Déploiement du Persistent Volume..."
kubectl apply -f k8s/db-pv.yaml --validate=false

echo "[8/9] Déploiement du Persistent Volume Claim..."
kubectl apply -n lab5-app -f k8s/db-pvc.yaml --validate=false

echo "[9/9] Déploiement des manifests K8s..."
kubectl apply -n lab5-app -f k8s/db-deployment.yaml --validate=false
kubectl apply -n lab5-app -f k8s/db-service.yaml --validate=false
kubectl apply -n lab5-app -f k8s/web-deployment.yaml --validate=false
kubectl apply -n lab5-app -f k8s/web-service.yaml --validate=false

echo "Déploiement terminé."
echo "Vérifie avec : kubectl get all -n lab5-app"
