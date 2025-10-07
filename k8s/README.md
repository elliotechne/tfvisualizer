# Kubernetes Manifests for TFVisualizer

⚠️ **Important**: These YAML files are for **reference and manual deployment only**.

**Primary deployment method is Terraform** (see `../terraform/` directory).

---

This directory contains Kubernetes manifest files for deploying TFVisualizer on any Kubernetes cluster.

> 💡 **All these resources are already defined in Terraform code**. See [TERRAFORM_NOTE.md](TERRAFORM_NOTE.md) for details.

## 📋 Files

- `namespace.yaml` - Kubernetes namespace for TFVisualizer
- `postgres.yaml` - PostgreSQL StatefulSet and Service
- `redis.yaml` - Redis StatefulSet and Service
- `secrets.yaml.example` - Secret configuration (copy to `secrets.yaml` and fill in values)
- `deployment.yaml` - Application Deployment, Service, HPA, and PDB configurations

## 🚀 Quick Deploy

### 1. Setup kubectl

```bash
# For DigitalOcean Kubernetes
doctl kubernetes cluster kubeconfig save <cluster-name>

# Verify connection
kubectl cluster-info
```

### 2. Create Namespace

```bash
kubectl apply -f namespace.yaml
```

### 3. Deploy PostgreSQL

```bash
kubectl apply -f postgres.yaml
```

### 4. Deploy Redis

```bash
kubectl apply -f redis.yaml
```

### 5. Configure Secrets

```bash
# Copy example secrets file
cp secrets.yaml.example secrets.yaml

# Edit with your values (match database passwords from postgres.yaml/redis.yaml)
nano secrets.yaml

# Apply secrets
kubectl apply -f secrets.yaml
```

### 6. Deploy Application

```bash
kubectl apply -f deployment.yaml
```

### 7. Verify Deployment

```bash
# Check all pods
kubectl get pods -n tfvisualizer

# Check all services
kubectl get svc -n tfvisualizer

# Check statefulsets
kubectl get statefulsets -n tfvisualizer

# Check HPA
kubectl get hpa -n tfvisualizer

# Get load balancer IP
kubectl get svc tfvisualizer-service -n tfvisualizer -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🔧 Management Commands

### View Logs

```bash
# All pods
kubectl logs -f -l app=tfvisualizer -n tfvisualizer

# Specific pod
kubectl logs -f <pod-name> -n tfvisualizer
```

### Scale Deployment

```bash
# Manual scaling
kubectl scale deployment tfvisualizer-app --replicas=5 -n tfvisualizer

# Check scaling
kubectl get pods -n tfvisualizer
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/tfvisualizer-app tfvisualizer=tfvisualizer/tfvisualizer:v2.0.0 -n tfvisualizer

# Check rollout status
kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer

# Rollback if needed
kubectl rollout undo deployment/tfvisualizer-app -n tfvisualizer
```

### Debug

```bash
# Describe pod
kubectl describe pod <pod-name> -n tfvisualizer

# Get events
kubectl get events -n tfvisualizer --sort-by='.lastTimestamp'

# Shell into pod
kubectl exec -it <pod-name> -n tfvisualizer -- /bin/sh

# Port forward for local testing
kubectl port-forward svc/tfvisualizer-service 8080:80 -n tfvisualizer
```

### Update Secrets

```bash
# Edit secrets
kubectl edit secret tfvisualizer-config -n tfvisualizer

# Or apply updated file
kubectl apply -f secrets.yaml

# Restart pods to pick up changes
kubectl rollout restart deployment/tfvisualizer-app -n tfvisualizer
```

## 🔒 Security Best Practices

### 1. Use Sealed Secrets (Recommended)

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal

# Seal your secrets
kubeseal --format yaml < secrets.yaml > sealed-secrets.yaml

# Apply sealed secrets
kubectl apply -f sealed-secrets.yaml
```

### 2. Use External Secrets Operator

```bash
# Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Configure secret store (DigitalOcean, AWS, etc.)
# Apply ExternalSecret resources
```

### 3. RBAC Configuration

```bash
# Create service account
kubectl create serviceaccount tfvisualizer -n tfvisualizer

# Create role and role binding
kubectl apply -f rbac.yaml
```

## 📊 Monitoring

### Check Resource Usage

```bash
# Pod resource usage
kubectl top pods -n tfvisualizer

# Node resource usage
kubectl top nodes
```

### View Metrics

```bash
# HPA metrics
kubectl describe hpa tfvisualizer-hpa -n tfvisualizer

# Pod disruption budget
kubectl get pdb -n tfvisualizer
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
- name: Deploy to Kubernetes
  run: |
    doctl kubernetes cluster kubeconfig save ${{ secrets.CLUSTER_NAME }}
    kubectl set image deployment/tfvisualizer-app tfvisualizer=${{ env.IMAGE }} -n tfvisualizer
    kubectl rollout status deployment/tfvisualizer-app -n tfvisualizer
```

### GitOps with ArgoCD

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create ArgoCD application
argocd app create tfvisualizer \
  --repo https://github.com/yourorg/tfvisualizer \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace tfvisualizer
```

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -f deployment.yaml
kubectl delete -f secrets.yaml
kubectl delete -f namespace.yaml

# Or delete namespace (removes everything)
kubectl delete namespace tfvisualizer
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [DigitalOcean Kubernetes Guide](https://docs.digitalocean.com/products/kubernetes/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
