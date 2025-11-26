#!/usr/bin/env bash
set -e

IMAGE_NAME="mohamedessid/lab5-web:1.0"

echo "[1/4] Build de l'image Docker..."
docker build -t "$IMAGE_NAME" .

echo "[2/4] Push de l'image vers le registre..."
docker push "$IMAGE_NAME"

echo "[3/4] Création du namespace..."
kubectl apply -f k8s/namespace.yaml

echo "[4/4] Déploiement des manifests K8s..."
kubectl apply -n lab5-app -f k8s/db-deployment.yaml
kubectl apply -n lab5-app -f k8s/db-service.yaml
kubectl apply -n lab5-app -f k8s/web-deployment.yaml
kubectl apply -n lab5-app -f k8s/web-service.yaml

echo "Déploiement terminé."
echo "Vérifie avec : kubectl get all -n lab5-app"
