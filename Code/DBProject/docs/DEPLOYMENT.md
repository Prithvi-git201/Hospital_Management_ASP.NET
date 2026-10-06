# ClinicManagementSystem — Deployment Guide

## Overview

This guide covers containerizing and deploying the **ClinicManagementSystem** ASP.NET Web Forms application (.NET Framework 4.8) to **AWS EKS** using Windows containers.

- **Technology**: ASP.NET Web Forms, .NET Framework 4.8
- **Container Base Image**: `mcr.microsoft.com/dotnet/framework/runtime:4.8` (Windows Server Core)
- **Target Platform**: AWS EKS (Windows node pool)
- **Application Port**: 80 (IIS)
- **Health Endpoint**: `/Health.aspx`

---

## Prerequisites

### Local Development
| Tool | Version | Purpose |
|------|---------|---------|
| Docker Desktop | 4.x+ | Build and run Windows containers |
| Windows 10/11 or Windows Server | — | Required for Windows containers |
| AWS CLI | 2.x | ECR authentication and EKS management |
| kubectl | 1.27+ | Kubernetes cluster management |

### AWS EKS Requirements
- AWS account with IAM permissions for EKS, ECR, and ALB
- EKS cluster with **Windows node group** (Windows Server 2019/2022)
- AWS Load Balancer Controller installed on the cluster
- `kubectl` configured for the target cluster

---

## Project Structure

```
Code/DBProject/
├── Dockerfile                  # Multi-stage Windows container build
├── docker-compose.yml          # Local development compose file
├── .dockerignore               # Docker build context exclusions
├── kubernetes/
│   ├── namespace.yaml          # Kubernetes namespace
│   ├── deployment.yaml         # Application deployment (Windows nodes)
│   ├── service.yaml            # ClusterIP service
│   └── ingress.yaml            # AWS ALB ingress
├── scripts/
│   ├── build-push.sh           # Linux/macOS build & push script
│   ├── build-push.bat          # Windows build & push script
│   ├── deploy-image.sh         # Linux/macOS EKS deploy script
│   └── deploy-image.bat        # Windows EKS deploy script
└── docs/
    └── DEPLOYMENT.md           # This file
```

---

## Environment Variables

The application reads configuration from environment variables at runtime:

| Variable | Description | Required |
|----------|-------------|----------|
| `DB_CONNECTION_STRING` | Full SQL Server connection string | Recommended |
| `DB_HOST` | SQL Server hostname (used if full string not set) | Optional |
| `DB_NAME` | Database name (default: `DBProject`) | Optional |
| `DB_USER` | Database username | Optional |
| `DB_PASSWORD` | Database password | Optional |
| `REDIS_HOST` | Redis/ElastiCache hostname for session state | Required for multi-pod |
| `REDIS_PORT` | Redis port (default: `6379`) | Optional |
| `REDIS_ACCESS_KEY` | Redis authentication key | Optional |
| `APPINSIGHTS_INSTRUMENTATIONKEY` | Application Insights key | Optional |

---

## Local Development with Docker Compose

### 1. Switch Docker to Windows Containers

In Docker Desktop, right-click the tray icon → **Switch to Windows containers**.

### 2. Configure Environment

Create a `.env` file in the project root (never commit this):

```env
DB_HOST=your-sql-server-host
DB_NAME=DBProject
DB_USER=sa
DB_PASSWORD=YourPassword123
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_ACCESS_KEY=your-redis-key
APPINSIGHTS_INSTRUMENTATIONKEY=your-key
```

### 3. Build and Run

```bash
# From repository root
cd Code/DBProject
docker-compose up --build
```

### 4. Access the Application

- Application: http://localhost:80
- Health Check: http://localhost:80/Health.aspx

---

## Build and Push Docker Image

### Linux/macOS

```bash
# Make script executable
chmod +x Code/DBProject/scripts/build-push.sh

# Run from repository root
./Code/DBProject/scripts/build-push.sh
```

### Windows

```cmd
# Run from repository root
Code\DBProject\scripts\build-push.bat
```

The script will prompt you to:
1. Choose registry (AWS ECR or Docker Hub)
2. Enter registry credentials and details
3. Specify an image tag (defaults to `latest`)

**Important**: Windows container images must be built on a Windows host with Docker Desktop in Windows container mode.

---

## AWS EKS Deployment

### Step 1: Prepare EKS Cluster with Windows Node Group

```bash
# Create a Windows node group (if not already present)
eksctl create nodegroup \
  --cluster YOUR_CLUSTER_NAME \
  --name windows-nodes \
  --node-type m5.xlarge \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --node-ami-family WindowsServer2019FullContainer \
  --region YOUR_AWS_REGION
```

### Step 2: Install AWS Load Balancer Controller

```bash
# Add the EKS chart repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Step 3: Configure kubectl

```bash
aws eks update-kubeconfig --region YOUR_AWS_REGION --name YOUR_CLUSTER_NAME
kubectl cluster-info
```

### Step 4: Deploy Using Script

#### Linux/macOS

```bash
chmod +x Code/DBProject/scripts/deploy-image.sh
./Code/DBProject/scripts/deploy-image.sh
```

#### Windows

```cmd
Code\DBProject\scripts\deploy-image.bat
```

The script will prompt for:
- AWS Region and EKS cluster name
- Full Docker image URI (from ECR or Docker Hub)
- All required environment variables

### Step 5: Manual Deployment (Alternative)

```bash
# 1. Update the image URI in deployment.yaml
sed -i 's|{{IMAGE_URI}}|YOUR_IMAGE_URI|g' Code/DBProject/kubernetes/deployment.yaml

# 2. Apply manifests in order
kubectl apply -f Code/DBProject/kubernetes/namespace.yaml
kubectl apply -f Code/DBProject/kubernetes/deployment.yaml
kubectl apply -f Code/DBProject/kubernetes/service.yaml
kubectl apply -f Code/DBProject/kubernetes/ingress.yaml

# 3. Wait for rollout
kubectl rollout status deployment/clinicmanagementsystem -n clinicmanagementsystem

# 4. Verify
kubectl get pods,svc,ingress -n clinicmanagementsystem
```

---

## Kubernetes Resource Details

### Namespace
- Name: `clinicmanagementsystem`

### Deployment
- Replicas: 2 (rolling update strategy)
- Node selector: `kubernetes.io/os: windows`
- Resource requests: CPU 250m, Memory 512Mi
- Resource limits: CPU 500m, Memory 1Gi
- Liveness probe: `GET /Health.aspx` (initial delay: 90s)
- Readiness probe: `GET /Health.aspx` (initial delay: 60s)

### Service
- Type: ClusterIP
- Port: 80 → 80

### Ingress
- Class: AWS ALB (internet-facing)
- Host: `clinicmanagementsystem.example.com` (update to your domain)
- Health check path: `/Health.aspx`

---

## Scaling

### Manual Scaling

```bash
kubectl scale deployment clinicmanagementsystem -n clinicmanagementsystem --replicas=4
```

### Horizontal Pod Autoscaler

```bash
kubectl autoscale deployment clinicmanagementsystem \
  -n clinicmanagementsystem \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

---

## Rolling Updates

```bash
# Update image
kubectl set image deployment/clinicmanagementsystem \
  clinicmanagementsystem=NEW_IMAGE_URI \
  -n clinicmanagementsystem

# Monitor rollout
kubectl rollout status deployment/clinicmanagementsystem -n clinicmanagementsystem
```

---

## Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/clinicmanagementsystem -n clinicmanagementsystem

# Rollback to specific revision
kubectl rollout history deployment/clinicmanagementsystem -n clinicmanagementsystem
kubectl rollout undo deployment/clinicmanagementsystem -n clinicmanagementsystem --to-revision=2
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n clinicmanagementsystem

# Describe pod for events
kubectl describe pod POD_NAME -n clinicmanagementsystem

# View logs
kubectl logs POD_NAME -n clinicmanagementsystem
kubectl logs -l app=clinicmanagementsystem -n clinicmanagementsystem --tail=100
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `ImagePullBackOff` | ECR auth expired or wrong image URI | Re-authenticate ECR; verify image URI |
| `Pending` (no Windows nodes) | No Windows node group | Add Windows node group to EKS cluster |
| `CrashLoopBackOff` | App startup failure | Check logs; verify DB_CONNECTION_STRING |
| Health probe failing | App not ready / wrong path | Verify `/Health.aspx` returns HTTP 200 |
| Session errors | Redis not configured | Set REDIS_HOST and REDIS_ACCESS_KEY |
| DB connection refused | Wrong DB_HOST or firewall | Check security groups; verify DB_HOST |

### Ingress Not Getting Address

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify ingress annotations
kubectl describe ingress clinicmanagementsystem-ingress -n clinicmanagementsystem
```

---

## Security Considerations

1. **Secrets Management**: Use AWS Secrets Manager or Kubernetes Secrets for DB_PASSWORD and REDIS_ACCESS_KEY instead of plain environment variables.
2. **Network Policies**: Restrict pod-to-pod communication using Kubernetes NetworkPolicies.
3. **IAM Roles for Service Accounts (IRSA)**: Use IRSA for ECR pull permissions instead of static credentials.
4. **Security Groups**: Ensure EKS node security groups allow traffic only from the ALB.
5. **TLS/HTTPS**: Configure ACM certificate ARN in ingress annotations for HTTPS:
   ```yaml
   alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:REGION:ACCOUNT:certificate/CERT-ID
   alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
   ```
6. **Image Scanning**: Enable ECR image scanning on push to detect vulnerabilities.

---

## .NET Framework Specific Notes

- **Windows Containers Only**: .NET Framework 4.8 requires Windows containers. Ensure your EKS node group uses Windows AMIs.
- **IIS Hosting**: The application is hosted by IIS inside the container. The `ServiceMonitor.exe` entrypoint monitors the `w3svc` Windows service.
- **Session State**: The application uses Redis for distributed session state (required for multi-pod deployments). Configure `REDIS_HOST` and `REDIS_ACCESS_KEY`.
- **Application Insights**: Telemetry is configured via `ApplicationInsights.config`. Set `APPINSIGHTS_INSTRUMENTATIONKEY` for monitoring.
- **Startup Time**: Windows containers take longer to start than Linux containers. The liveness probe has a 90-second initial delay to accommodate this.
- **Image Size**: .NET Framework Windows container images are large (several GB). Ensure sufficient disk space on nodes and ECR storage.

---

## Useful Commands Reference

```bash
# View all resources in namespace
kubectl get all -n clinicmanagementsystem

# Stream logs
kubectl logs -f -l app=clinicmanagementsystem -n clinicmanagementsystem

# Execute into pod (Windows)
kubectl exec -it POD_NAME -n clinicmanagementsystem -- powershell

# Port-forward for local testing
kubectl port-forward svc/clinicmanagementsystem-service 8080:80 -n clinicmanagementsystem

# Delete all resources
kubectl delete namespace clinicmanagementsystem
```
