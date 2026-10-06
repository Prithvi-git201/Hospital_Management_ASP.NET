#!/bin/bash
set -e

# =============================================================================
# build-push.sh - Build and push Docker image for ClinicManagementSystem
# Target: AWS EKS (Windows node pool)
# Usage: ./scripts/build-push.sh
# =============================================================================

PROJECT_NAME="clinicmanagementsystem"
DOCKERFILE_PATH="Code/DBProject/Dockerfile"

echo "=============================================="
echo "  ClinicManagementSystem - Build & Push"
echo "=============================================="
echo ""

# Sanitize project name: lowercase, replace non-alphanumeric with hyphens, trim hyphens
IMAGE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')

# Prompt for image tag
read -p "Enter image tag (press Enter for 'latest'): " IMAGE_TAG_INPUT
IMAGE_TAG=$(echo "$IMAGE_TAG_INPUT" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')
if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="latest"
fi

echo ""
echo "Select container registry:"
echo "  1. AWS ECR"
echo "  2. Docker Hub"
read -p "Enter choice (1 or 2): " REGISTRY_CHOICE

echo ""

if [ "$REGISTRY_CHOICE" = "1" ]; then
  # ---- AWS ECR ----
  read -p "Enter AWS Region (e.g. us-east-1): " AWS_REGION
  read -p "Enter AWS Account ID: " AWS_ACCOUNT_ID
  read -p "Enter ECR repository name (default: $IMAGE_NAME): " ECR_REPO_INPUT
  ECR_REPO="${ECR_REPO_INPUT:-$IMAGE_NAME}"
  ECR_REPO=$(echo "$ECR_REPO" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9/_-' '-' | sed 's/^-*//;s/-*$//')

  REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}:${IMAGE_TAG}"

  echo ""
  echo "Authenticating with AWS ECR..."
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_URL"
  if [ $? -ne 0 ]; then
    echo "ERROR: ECR login failed."
    exit 1
  fi

  echo "Checking/creating ECR repository: $ECR_REPO ..."
  aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"

elif [ "$REGISTRY_CHOICE" = "2" ]; then
  # ---- Docker Hub ----
  read -p "Enter Docker Hub username: " DOCKER_USERNAME
  read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
  echo ""
  read -p "Enter Docker Hub repository (default: $DOCKER_USERNAME/$IMAGE_NAME): " DOCKERHUB_REPO_INPUT
  DOCKERHUB_REPO="${DOCKERHUB_REPO_INPUT:-$DOCKER_USERNAME/$IMAGE_NAME}"

  FULL_IMAGE_NAME="${DOCKERHUB_REPO}:${IMAGE_TAG}"

  echo ""
  echo "Authenticating with Docker Hub..."
  echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
  if [ $? -ne 0 ]; then
    echo "ERROR: Docker Hub login failed."
    exit 1
  fi

else
  echo "ERROR: Invalid choice. Please enter 1 or 2."
  exit 1
fi

echo ""
echo "Building Docker image..."
echo "  Image : $FULL_IMAGE_NAME"
echo "  Dockerfile: $DOCKERFILE_PATH"
echo "  Context: . (repository root)"
echo ""

# NOTE: Build context is repository root; Dockerfile path is relative
docker build -f "$DOCKERFILE_PATH" -t "$FULL_IMAGE_NAME" .
if [ $? -ne 0 ]; then
  echo "ERROR: Docker build failed."
  exit 1
fi

echo ""
echo "Pushing image to registry..."
docker push "$FULL_IMAGE_NAME"
if [ $? -ne 0 ]; then
  echo "ERROR: Docker push failed."
  exit 1
fi

echo ""
echo "=============================================="
echo "  SUCCESS: Image pushed successfully!"
echo "  $FULL_IMAGE_NAME"
echo "=============================================="
