# Qualys Cloud Agent for Kubernetes

Deploy Qualys Cloud Agent to your Kubernetes cluster in a few minutes. This uses a universal container that automatically figures out your OS and architecture.

## What's included

Three files:
- `qualys-daemonset.yaml` - The Kubernetes deployment
- `setup-qualys.sh` - Script to configure your credentials  
- `README.md` - This file

The container automatically detects your Linux distribution and architecture, then installs the right Qualys package and starts the service.

## Quick setup

Run the credential setup:
```bash
chmod +x setup-qualys.sh
./setup-qualys.sh
```

Deploy it:
```bash
kubectl apply -f qualys-daemonset.yaml
```

Check that it's working:
```bash
kubectl get pods -n qualys
kubectl logs -n qualys -l app=qualys-cloud-agent
```

The agent should show up in your Qualys console within a few minutes.

## What you need

A Kubernetes cluster and your Qualys credentials. You'll need cluster admin permissions since this installs packages on the host nodes.

Get your credentials from the Qualys console under VMDR > Downloads > Cloud Agent. You need the Activation ID, Customer ID, and Server URI.

## Manual credential setup

If you don't want to use the setup script:

```bash
kubectl create namespace qualys

kubectl create secret generic qualys-agent-credentials \
  --namespace=qualys \
  --from-literal=ACTIVATION_ID="your-activation-id" \
  --from-literal=CUSTOMER_ID="your-customer-id"

kubectl create configmap qualys-agent-config \
  --namespace=qualys \
  --from-literal=SERVER_URI="https://your-qualys-server/CloudAgent/" \
  --from-literal=LOG_LEVEL="3"
```

## Supported stuff

Works on Ubuntu, Debian, RHEL, CentOS, CoreOS, and other Linux distributions. Handles both x86_64 and ARM64 architectures automatically.

## If something goes wrong

Pods not starting? Check `kubectl describe pods -n qualys` and make sure your cluster allows privileged containers.

Agent not connecting? Double-check your credentials and Server URI. The Server URI needs to match your Qualys region.

Can't deploy? Make sure you have cluster admin permissions.

## Updates

To get newer agent versions:
```bash
kubectl rollout restart daemonset qualys-cloud-agent -n qualys
```

**Version pinning (optional):**
If you want to control exactly which version you're using, edit the DaemonSet:
```yaml
# Pin to specific version
image: nelssec/qualys-agent-bootstrapper:v1.1.0

# Or use latest (auto-updates)
image: nelssec/qualys-agent-bootstrapper:latest
```

## Cleanup

Remove everything:
```bash
kubectl delete namespace qualys
```

## How it works

The container mounts the host filesystem and uses chroot to install the Qualys agent directly on each node. It detects the OS type and architecture, picks the right package, and handles the installation. The agent runs as a native systemd service, not just in the container.

This approach eliminates the download-at-runtime issues from the original Qualys deployment method and works in air-gapped environments.
