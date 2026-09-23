#!/bin/bash
set -e

echo "=========================================="
echo "Deploy to ECS"
echo "=========================================="
echo ""

# Get cluster and service names from Terraform
cd terraform
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE=$(terraform output -raw ecs_service_name 2>/dev/null)
AWS_REGION="${AWS_REGION:-us-east-1}"
cd ..

if [ -z "$CLUSTER" ] || [ -z "$SERVICE" ]; then
    echo "❌ Error: Could not get cluster or service name"
    echo "Make sure Terraform has been applied first"
    exit 1
fi

echo "📋 Configuration:"
echo "  Cluster: $CLUSTER"
echo "  Service: $SERVICE"
echo "  Region: $AWS_REGION"
echo ""

# Force new deployment
echo "🚀 Forcing new ECS deployment..."
aws ecs update-service \
    --cluster $CLUSTER \
    --service $SERVICE \
    --force-new-deployment \
    --region $AWS_REGION \
    --no-cli-pager

echo ""
echo "⏳ Waiting for service to stabilize..."
echo "This may take 2-5 minutes..."
echo ""

aws ecs wait services-stable \
    --cluster $CLUSTER \
    --services $SERVICE \
    --region $AWS_REGION

echo ""
echo "✅ Deployment complete!"
echo ""

# Show service status
echo "📊 Service Status:"
aws ecs describe-services \
    --cluster $CLUSTER \
    --services $SERVICE \
    --region $AWS_REGION \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
    --output table

echo ""
echo "To view logs:"
echo "  aws logs tail /ecs/flask-demo --follow"
echo ""
echo "To get instance IPs:"
echo "  bash scripts/get-instance-ips.sh"
