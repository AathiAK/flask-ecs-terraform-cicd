# Complete Setup Guide - GitHub Actions CI/CD

## 📋 Step-by-Step Setup

### Step 1: Prepare AWS (5 minutes)

#### 1.1 Create IAM User for GitHub Actions

# Create user
aws iam create-user --user-name github-actions-ecs

# Create access key
aws iam create-access-key --user-name github-actions-ecs

# Save the output - you'll need:
# - AccessKeyId
# - SecretAccessKey


#### 1.2 Attach IAM Policy

# Create policy file
cat > github-actions-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ec2:DescribeInstances"
      ],
      "Resource": ""
    }
  ]
}
POLICY

# Create policy
aws iam create-policy \
  --policy-name GitHubActionsECSPolicy \
  --policy-document file://github-actions-policy.json

# Attach to user
aws iam attach-user-policy \
  --user-name github-actions-ecs \
  --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/GitHubActionsECSPolicy


### Step 2: Deploy Infrastructure (10 minutes)

# Clone repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars

Add your values:

vpc_id        = "vpc-xxxxx"      # Your VPC ID
key_name      = "your-key-name"  # Your SSH key
instance_type = "t3.micro"
aws_region    = "us-east-1"

Deploy:
terraform init
terraform plan
terraform apply -auto-approve

Save outputs:
terraform output > ../terraform-outputs.txt


### Step 3: Build Initial Image (2 minutes)
cd ..
 scripts/build-and-push.sh


This will:
1. Login to ECR
2. Build Docker image
3. Tag image as `latest`
4. Push to ECR

### Step 4: Deploy Initial Version (2 minutes)
 scripts/deploy-ecs.sh


Wait for deployment to complete (~2 minutes)
Test:
 scripts/get-instance-ips.sh

You should see output like:

✅ Found running instances:
  Instance IP: 54.123.45.67
  ✓ Home endpoint (/) - OK
  ✓ Health endpoint (/health) - OK
  ✓ Info endpoint (/info) - OK


### Step 5: Setup GitHub Repository (5 minutes)

#### 5.1 Create GitHub Repository


# On GitHub.com:
# 1. Click "New repository"
# 2. Name it (e.g., "flask-ecs-demo")
# 3. Don't initialize with README
# 4. Create repository


#### 5.2 Configure GitHub Secrets

Go to: Repository → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | From Step 1.1 |
| `AWS_SECRET_ACCESS_KEY` | From Step 1.1 |

Screenshot guide:
1. Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `AWS_ACCESS_KEY_ID`
4. Value: Paste your access key
5. Click "Add secret"
6. Repeat for `AWS_SECRET_ACCESS_KEY`

#### 5.3 Push Code to GitHub


# In your project directory
git init
git add .
git commit -m "Initial commit with CI/CD pipeline"

# Add remote
git remote add origin https://github.com/yourusername/your-repo.git

# Push
git branch -M main
git push -u origin main


Watch the deployment:
1. Go to GitHub → Actions tab
2. You should see a workflow run starting
3. Click on it to watch live logs

### Step 6: Verify CI/CD Works (2 minutes)

#### 6.1 Make a Test Change


# Edit the app
vim docker/app.py


Change something simple:
python
@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from ECS EC2 - CI/CD is working! 🚀',  # Changed this line
        ...
    })


#### 6.2 Commit and Push


git add docker/app.py
git commit -m "Test CI/CD pipeline"
git push origin main


#### 6.3 Watch Deployment

1. Go to GitHub → Actions
2. See new workflow run
3. Watch it:
   - Build Docker image
   - Push to ECR
   - Deploy to ECS
   - Run health checks

#### 6.4 Test New Version


# Get instance IP
IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=flask-demo-ecs-instance" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# Test (should see new message)
curl http://$IP:5000/


## ✅ Setup Complete!

You should now have:
- ✅ Infrastructure deployed on AWS
- ✅ Docker image in ECR
- ✅ ECS service running
- ✅ GitHub Actions configured
- ✅ Automatic deployments working

## 🎯 Next Steps

### Daily Workflow


# 1. Make code changes
vim docker/app.py

# 2. Commit
git add .
git commit -m "Your changes"

# 3. Push (triggers automatic deployment)
git push origin main

# 4. Watch deployment in GitHub Actions
# 5. Test at http://<instance-ip>:5000/


### Monitor Deployments


# View logs
aws logs tail /ecs/flask-demo --follow

# Check ECS service
aws ecs describe-services \
  --cluster flask-demo-cluster \
  --services flask-demo-service

# Get instance IPs
 scripts/get-instance-ips.sh


## 🐛 Troubleshooting

### GitHub Actions Fails

Error: AWS auth failed

Solution: Check GitHub Secrets
- Verify AWS_ACCESS_KEY_ID
- Verify AWS_SECRET_ACCESS_KEY
- Ensure IAM user has correct permissions


Error: Task definition not found

Solution: Run initial deployment
 scripts/deploy-ecs.sh


Error: ECR login failed

Solution: Check IAM permissions
aws ecr describe-repositories


### ECS Deployment Issues


# Check service events
aws ecs describe-services \
  --cluster flask-demo-cluster \
  --services flask-demo-service \
  --query 'services[0].events[0:5]'

# Check task status
aws ecs list-tasks --cluster flask-demo-cluster

# View logs
aws logs tail /ecs/flask-demo --since 10m


### Health Check Fails


# SSH to instance
IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=flask-demo-ecs-instance" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

ssh -i your-key.pem ec2-user@$IP

# Check Docker containers
docker ps

# Check logs
docker logs <container-id>


## 📊 Validate Setup

Run this checklist:


# 1. Infrastructure exists
terraform output

# 2. ECR has image
aws ecr list-images --repository-name flask-demo

# 3. ECS service running
aws ecs describe-services \
  --cluster flask-demo-cluster \
  --services flask-demo-service \
  --query 'services[0].status'

# 4. EC2 instance running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=flask-demo-ecs-instance" \
            "Name=instance-state-name,Values=running"

# 5. GitHub secrets configured
# Go to: GitHub → Settings → Secrets → Actions

# 6. Application responding
curl http://<instance-ip>:5000/health


## 🎓 Understanding the Workflow

### What Happens on Git Push

1. Trigger: Push to `main` branch
2. Checkout: GitHub clones your code
3. AWS Auth: Uses secrets to authenticate
4. ECR Login: Gets token to push images
5. Build: Builds Docker image from `docker/`
6. Tag: Tags with commit SHA and `latest`
7. Push: Pushes image to ECR
8. Task Def: Downloads current ECS task definition
9. Update: Updates task def with new image
10. Deploy: Registers new task def and updates service
11. Wait: Waits for service stability
12. Test: Gets instance IPs and tests health
13. Report: Shows deployment summary

### Files Involved

- `.github/workflows/deploy.yml`: CI/CD pipeline
- `docker/Dockerfile`: Image build instructions
- `docker/app.py`: Application code
- `terraform/main.tf`: Infrastructure definition

## 💡 Tips

1. Test locally: `docker build -t test docker/` before pushing
2. Watch Actions: Keep Actions tab open during push
3. Check logs: `aws logs tail /ecs/flask-demo --follow`
4. Rollback: `git revert HEAD && git push` to undo
5. Branch strategy: Use feature branches, merge to main

## 🔄 Update Workflow

To modify the CI/CD pipeline:


# Edit workflow
vim .github/workflows/deploy.yml

# Commit and push
git add .github/workflows/deploy.yml
git commit -m "Updated CI/CD pipeline"
git push origin main


---

Setup complete! Your Flask app now deploys automatically on every push! 🎉
