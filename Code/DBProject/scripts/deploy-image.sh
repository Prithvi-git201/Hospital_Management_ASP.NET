#!/bin/bash
set -e
set -o pipefail

# =============================================================================
# deploy-image.sh - Deploy ClinicManagementSystem to AWS EKS
# Usage: ./scripts/deploy-image.sh
# Requirements: aws-cli, kubectl
# =============================================================================

NAMESPACE="clinicmanagementsystem"
APP_NAME="clinicmanagementsystem"
K8S_DIR="kubernetes"

echo "=============================================="
echo "  ClinicManagementSystem - Deploy to AWS EKS"
echo "=============================================="
echo ""

# ---- Collect deployment inputs ----
read -p "Enter AWS Region (e.g. us-east-1): " AWS_REGION
if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS Region is required."
  exit 1
fi

read -p "Enter EKS Cluster Name: " CLUSTER_NAME
if [ -z "$CLUSTER_NAME" ]; then
  echo "ERROR: EKS Cluster Name is required."
  exit 1
fi

read -p "Enter full Docker image URI (e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com/clinicmanagementsystem:latest): " IMAGE_URI
if [ -z "$IMAGE_URI" ]; then
  echo "ERROR: Docker image URI is required."
  exit 1
fi

echo ""
echo "---- Application Environment Variables ----"
echo "Press Enter to skip any variable (it will remain as placeholder)."
echo ""

read -p "Enter DB_CONNECTION_STRING (full SQL Server connection string, or Enter to skip): " DB_CONNECTION_STRING
read -p "Enter DB_HOST (SQL Server host, or Enter to skip): " DB_HOST
read -p "Enter DB_NAME (database name, default: DBProject): " DB_NAME
read -p "Enter DB_USER (database user, or Enter to skip): " DB_USER
read -s -p "Enter DB_PASSWORD (database password, or Enter to skip): " DB_PASSWORD
echo ""
read -p "Enter REDIS_HOST (ElastiCache/Redis host, or Enter to skip): " REDIS_HOST
read -p "Enter REDIS_PORT (Redis port, default: 6379): " REDIS_PORT
read -s -p "Enter REDIS_ACCESS_KEY (Redis access key, or Enter to skip): " REDIS_ACCESS_KEY
echo ""
read -p "Enter APPINSIGHTS_INSTRUMENTATIONKEY (Application Insights key, or Enter to skip): " APPINSIGHTS_INSTRUMENTATIONKEY

echo ""
echo "---- Configuring kubectl for EKS ----"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to configure kubectl for EKS cluster '$CLUSTER_NAME'."
  exit 1
fi

echo "Verifying cluster connectivity..."
kubectl cluster-info || { echo "ERROR: Cannot connect to EKS cluster."; exit 1; }

echo ""
echo "---- Updating Kubernetes manifests ----"

# Work on copies to avoid modifying originals
cp -r "$K8S_DIR" /tmp/k8s-deploy-$$

# Replace IMAGE_URI placeholder
sed -i "s|{{IMAGE_URI}}|${IMAGE_URI}|g" /tmp/k8s-deploy-$$/deployment.yaml

# Replace environment variable placeholders
[ -n "$DB_CONNECTION_STRING" ] && sed -i "s|{{DB_CONNECTION_STRING}}|${DB_CONNECTION_STRING}|g" /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$DB_HOST" ]              && sed -i "s|{{DB_HOST}}|${DB_HOST}|g"                           /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$DB_NAME" ]              && sed -i "s|{{DB_NAME}}|${DB_NAME}|g"                           /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$DB_USER" ]              && sed -i "s|{{DB_USER}}|${DB_USER}|g"                           /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$DB_PASSWORD" ]          && sed -i "s|{{DB_PASSWORD}}|${DB_PASSWORD}|g"                   /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$REDIS_HOST" ]           && sed -i "s|{{REDIS_HOST}}|${REDIS_HOST}|g"                     /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$REDIS_PORT" ]           && sed -i "s|{{REDIS_PORT}}|${REDIS_PORT}|g"                     /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$REDIS_ACCESS_KEY" ]     && sed -i "s|{{REDIS_ACCESS_KEY}}|${REDIS_ACCESS_KEY}|g"         /tmp/k8s-deploy-$$/deployment.yaml
[ -n "$APPINSIGHTS_INSTRUMENTATIONKEY" ] && sed -i "s|{{APPINSIGHTS_INSTRUMENTATIONKEY}}|${APPINSIGHTS_INSTRUMENTATIONKEY}|g" /tmp/k8s-deploy-$$/deployment.yaml

echo ""
echo "---- Applying Kubernetes manifests ----"

echo "[1/4] Applying namespace..."
kubectl apply -f /tmp/k8s-deploy-$$/namespace.yaml

echo "[2/4] Applying deployment..."
kubectl apply -f /tmp/k8s-deploy-$$/deployment.yaml

echo "[3/4] Applying service..."
kubectl apply -f /tmp/k8s-deploy-$$/service.yaml

echo "[4/4] Applying ingress..."
kubectl apply -f /tmp/k8s-deploy-$$/ingress.yaml

echo ""
echo "---- Waiting for deployment rollout ----"
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s
if [ $? -ne 0 ]; then
  echo "ERROR: Deployment rollout failed or timed out."
  echo "To rollback: kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}"
  rm -rf /tmp/k8s-deploy-$$
  exit 1
fi

echo ""
echo "---- Verifying deployed resources ----"
kubectl get pods,svc,ingress -n ${NAMESPACE}

echo ""
echo "---- Application Access ----"
INGRESS_HOST=$(kubectl get ingress ${APP_NAME}-ingress -n ${NAMESPACE} -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "pending")
echo "Application URL: http://${INGRESS_HOST}"
echo "Health Check:    http://${INGRESS_HOST}/Health.aspx"
echo ""
echo "Note: If using AWS ALB Ingress, the external hostname may take a few minutes to provision."
echo "      Run: kubectl get ingress -n ${NAMESPACE} to check the ADDRESS field."

# Cleanup temp files
rm -rf /tmp/k8s-deploy-$$

echo ""
echo "=============================================="
echo "  SUCCESS: Deployment complete!"
echo "=============================================="
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo "  kubectl logs -l app=${APP_NAME} -n ${NAMESPACE}"
echo "  kubectl rollout undo deployment/${APP_NAME} -n ${NAMESPACE}  # rollback"
