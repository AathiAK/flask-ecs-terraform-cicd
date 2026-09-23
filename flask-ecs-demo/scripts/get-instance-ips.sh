#!/bin/bash
set -e

echo "=========================================="
echo "Get EC2 Instance IPs and Test"
echo "=========================================="
echo ""

# Get instance IPs
echo "🔍 Finding EC2 instances..."
INSTANCE_IPS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=flask-demo-ecs-instance" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text)

if [ -z "$INSTANCE_IPS" ]; then
    echo "❌ No running instances found"
    echo ""
    echo "Check if instances are running:"
    echo "  aws ec2 describe-instances --filters 'Name=tag:Name,Values=flask-demo-ecs-instance'"
    exit 1
fi

echo "✅ Found running instances:"
echo ""

for IP in $INSTANCE_IPS; do
    echo "  Instance IP: $IP"
    echo "  Application: http://$IP:5000"
    echo ""
    
    # Test the application
    echo "  Testing endpoints..."
    
    # Test home endpoint
    if curl -s -f http://$IP:5000/ > /dev/null 2>&1; then
        echo "    ✓ Home endpoint (/) - OK"
        curl -s http://$IP:5000/ | jq -r '.message'
    else
        echo "    ✗ Home endpoint (/) - Failed"
    fi
    
    # Test health endpoint
    if curl -s -f http://$IP:5000/health > /dev/null 2>&1; then
        echo "    ✓ Health endpoint (/health) - OK"
    else
        echo "    ✗ Health endpoint (/health) - Failed"
    fi
    
    # Test info endpoint
    if curl -s -f http://$IP:5000/info > /dev/null 2>&1; then
        echo "    ✓ Info endpoint (/info) - OK"
    else
        echo "    ✗ Info endpoint (/info) - Failed"
    fi
    
    echo ""
done

echo "=========================================="
echo "📝 Quick Access Commands:"
echo ""
echo "Test application:"
for IP in $INSTANCE_IPS; do
    echo "  curl http://$IP:5000/"
done
echo ""
echo "SSH to instance (if needed):"
for IP in $INSTANCE_IPS; do
    echo "  ssh -i your-key.pem ec2-user@$IP"
done
echo ""
echo "View ECS logs:"
echo "  aws logs tail /ecs/flask-demo --follow"
