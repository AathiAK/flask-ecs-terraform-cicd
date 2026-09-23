#!/bin/bash
set -e

echo "=========================================="
echo "Docker Build & Push to ECR"
echo "=========================================="
echo ""

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Get ECR repository URL from Terraform
cd terraform
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null)
cd ..

if [ -z "$ECR_URL" ]; then
    echo "❌ Error: Could not get ECR repository URL"
    echo "Make sure Terraform has been applied first"
    exit 1
fi

echo "📋 Configuration:"
echo "  ECR URL: $ECR_URL"
echo "  Image Tag: $IMAGE_TAG"
echo "  Region: $AWS_REGION"
echo ""

# Login to ECR
echo "🔐 Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin ${ECR_URL%/*}

# Build Docker image
#echo "🏗️  Building Docker image..."
#cd docker
#docker build -t flask-demo:$IMAGE_TAG .

# Tag for ECR
#echo "🏷️  Tagging image..."
#docker tag flask-demo:$IMAGE_TAG $ECR_URL:$IMAGE_TAG

# Push to ECR
#echo "⬆️  Pushing to ECR..."
#docker push $ECR_URL:$IMAGE_TAG

echo "🏗️  Building & pushing multi-arch Docker image..."

cd docker

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $ECR_URL:$IMAGE_TAG \
  --push \
  .

echo ""
echo "✅ Build and push complete!"
echo ""
echo "Image: $ECR_URL:$IMAGE_TAG"
echo ""
echo "Next steps:"
echo "  1. Force ECS deployment: bash scripts/deploy-ecs.sh"
echo "  2. Or wait for ECS to pull the new image automatically"
