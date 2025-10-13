# Workaround: Use IP Address Instead of DNS

## Problem

Kubernetes DNS is not working - `nslookup` times out with "no servers could be reached"

## Temporary Workaround

Use the PostgreSQL pod's IP address directly instead of the service name.

### Step 1: Get PostgreSQL Pod IP

```bash
kubectl get pod postgres-0 -n tfvisualizer -o wide
```

Look for the `IP` column - it will be something like `10.244.0.x`

### Step 2: Update Connection String Temporarily

Edit `terraform/kubernetes.tf` and replace the hostname with the IP:

```hcl
DATABASE_URL = "postgresql://tfuser:${var.postgres_password}@10.244.0.X:5432/tfvisualizer"
DB_HOST      = "10.244.0.X"
```

Replace `10.244.0.X` with the actual IP from Step 1.

### Step 3: Apply

```bash
cd terraform
terraform apply
```

**⚠️ WARNING:** This is a temporary workaround only. The IP will change if the pod restarts.

---

## Permanent Fix: Fix Cluster DNS

The real issue is that Kubernetes DNS (CoreDNS/kube-dns) is not working. This needs to be fixed at the cluster level.

### For DigitalOcean Kubernetes:

Check if DNS is enabled on your cluster:

```bash
# Check DNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Should show cilium-operator or coredns pods Running
```

If no DNS pods exist, the cluster may need to be recreated or DNS needs to be installed.

### Manual CoreDNS Installation (if missing)

If DNS is completely missing:

```bash
kubectl apply -f https://raw.githubusercontent.com/coredns/deployment/master/kubernetes/coredns.yaml.sed
```

---

## Why DNS Doesn't Work

Common causes:
1. **CoreDNS/kube-dns not running** - Check: `kubectl get pods -n kube-system`
2. **DNS service doesn't exist** - Check: `kubectl get svc -n kube-system kube-dns`
3. **Network plugin issue** - DigitalOcean uses Cilium, might be misconfigured
4. **Cluster not fully initialized** - Wait or recreate cluster

---

## Check DigitalOcean Cluster Status

```bash
# Using doctl
doctl kubernetes cluster get tfvisualizer-production-k8s

# Check cluster is fully ready
kubectl get nodes
# All nodes should be Ready
```

If cluster is not healthy, consider recreating it via Terraform.

---

**Use the IP workaround only temporarily while fixing DNS!**
