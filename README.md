# Qualys Cloud Agent - Bundled RPM Container Deployment Guide

This guide covers building and deploying a containerized Qualys Cloud Agent with the RPM binary bundled directly into the image for Ubuntu worker nodes.

## Prerequisites

- Kubernetes cluster with Ubuntu worker nodes
- Docker or Podman for building images
- Container registry access (Docker Hub, ECR, GCR, etc.)
- Qualys Cloud Agent RPM binary from your Qualys subscription
- Qualys credentials (Activation ID, Customer ID, Server URI)

## Step 1: Prepare Build Environment

1. Create project directory:
```bash
mkdir qualys-k8s-bundled
cd qualys-k8s-bundled
```

2. Download Qualys Cloud Agent RPM:
   - Log into your Qualys console
   - Navigate to VMDR > Downloads > Cloud Agent
   - Download the Linux x86_64 RPM package
   - Rename it to `qualys-cloud-agent.rpm` and place in project directory

3. **Create directory structure:**
```
qualys-k8s-bundled/
├── Dockerfile
├── install.sh
├── configure-agent.sh
├── manage-secrets.sh
├── qualys-cloud-agent.rpm
├── k8s/
│   └── daemonset.yaml
└── build.sh
```

4. **Make scripts executable:**
```bash
chmod +x build.sh configure-agent.sh manage-secrets.sh install.sh
```

## Step 2: Build Container Image

1. Create build script:
```bash
#!/bin/bash
# build.sh

set -e

# Configuration - Update these values
REGISTRY="your-registry.com"
IMAGE_NAME="qualys-agent-bundled"
TAG="v1.0.0"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Building Qualys Cloud Agent container image..."
echo "Image: ${FULL_IMAGE}"

# Verify RPM exists
if [[ ! -f "qualys-cloud-agent.rpm" ]]; then
    echo "ERROR: qualys-cloud-agent.rpm not found in current directory"
    echo "Please download the RPM from Qualys console and place it here"
    exit 1
fi

# Build the image
docker build -t "${FULL_IMAGE}" .

echo "Build completed successfully!"
echo "To push to registry, run:"
echo "docker push ${FULL_IMAGE}"
```

2. Make build script executable and run:
```bash
chmod +x build.sh
./build.sh
```

3. Push to your container registry:
```bash
docker push your-registry.com/qualys-agent-bundled:v1.0.0
```

## Step 3: Configure Deployment with Secrets

The deployment uses Kubernetes secrets for sensitive credentials and ConfigMaps for non-sensitive configuration. This provides better security by:

- Storing sensitive data separately from configuration files
- Enabling secret rotation without modifying deployments
- Preventing credentials from appearing in plain text in YAML files
- Supporting encryption at rest for secret data

### Option A: Use the Configuration Helper Script

1. Update the DaemonSet YAML (`k8s/daemonset.yaml`):
   
   Required changes:
   - Replace `your-registry/qualys-agent-bundled:latest` with your actual image
   - Update placeholder values for credentials and configuration

2. Run the configuration script:
```bash
./configure-agent.sh
```

### Option B: Use the Secure Secret Management Script

For better security, use the dedicated secret management script:

1. Create secrets securely:
```bash
./manage-secrets.sh
```
   Choose option 1 to create/update credentials. This method:
   - Prompts for credentials without displaying them on screen
   - Creates Kubernetes secrets directly without storing credentials in files
   - Separates sensitive and non-sensitive configuration

2. Update only the container image in `k8s/daemonset.yaml`:
   ```yaml
   image: your-registry.com/qualys-agent-bundled:v1.0.0
   ```

### Manual Secret Creation

If you prefer to create secrets manually:

```bash
# Create namespace
kubectl create namespace qualys-system

# Create secret for sensitive credentials
kubectl create secret generic qualys-agent-credentials \
  --namespace=qualys-system \
  --from-literal=ACTIVATION_ID="your-activation-id" \
  --from-literal=CUSTOMER_ID="your-customer-id"

# Create configmap for non-sensitive configuration
kubectl create configmap qualys-agent-config \
  --namespace=qualys-system \
  --from-literal=SERVER_URI="https://your-qualys-server/CloudAgent/" \
  --from-literal=LOG_LEVEL="3"
```

## Step 4: Deploy to Kubernetes

1. Apply the configuration:
```bash
kubectl apply -f k8s/daemonset.yaml
```

2. Verify deployment:
```bash
# Check DaemonSet status
kubectl get daemonset -n qualys-system

# Check pod status on each node
kubectl get pods -n qualys-system -o wide

# Check logs
kubectl logs -n qualys-system -l app=qualys-cloud-agent --tail=50
```

3. **Verify agent installation on nodes:**
```bash
# Check if service is running on a node
kubectl exec -n qualys-system <pod-name> -- chroot /host systemctl status qualys-cloud-agent

# Check agent logs on host
kubectl exec -n qualys-system <pod-name> -- chroot /host journalctl -u qualys-cloud-agent -f
```

## Step 5: Monitoring and Troubleshooting

### Check Agent Status
```bash
# View all pods
kubectl get pods -n qualys-system

# Check specific pod logs
kubectl logs -n qualys-system qualys-cloud-agent-xxxxx

# Check agent service on host
kubectl exec -n qualys-system qualys-cloud-agent-xxxxx -- \
  chroot /host systemctl status qualys-cloud-agent

# Verify secrets and configmaps are accessible
kubectl exec -n qualys-system qualys-cloud-agent-xxxxx -- env | grep -E "(ACTIVATION_ID|CUSTOMER_ID|SERVER_URI)"
```

### Common Issues

1. Secret Access Errors:
   - Verify secret exists: `kubectl get secret qualys-agent-credentials -n qualys-system`
   - Check secret keys: `kubectl describe secret qualys-agent-credentials -n qualys-system`
   - Test secret access using the manage-secrets.sh script

2. Permission Errors:
   - Ensure DaemonSet has `privileged: true`
   - Verify SecurityContext capabilities

3. Installation Failures:
   - Check if `alien` package can be installed on Ubuntu nodes
   - Verify RPM file integrity in container

4. Service Start Issues:
   - Check systemd status on host system
   - Verify configuration file permissions
   - Ensure credentials are properly formatted

5. Network Connectivity:
   - Ensure nodes can reach Qualys servers
   - Check proxy settings if applicable
   - Verify SERVER_URI format and accessibility

### Updating the Agent

1. Build new image with updated RPM:
```bash
# Replace RPM file with newer version
# Update TAG in build.sh
./build.sh
docker push your-registry.com/qualys-agent-bundled:v1.1.0
```

2. Update DaemonSet:
```bash
# Update image tag in daemonset.yaml
kubectl apply -f k8s/daemonset.yaml
```

### Secret Management and Rotation

1. Rotate Qualys credentials:
```bash
# Use the secret management script
./manage-secrets.sh
# Choose option 1 to update credentials
```

2. Update configuration without credential changes:
```bash
# Update ConfigMap directly
kubectl patch configmap qualys-agent-config -n qualys-system --patch '{"data":{"LOG_LEVEL":"4"}}'

# Restart DaemonSet to pick up changes
kubectl rollout restart daemonset qualys-cloud-agent -n qualys-system
```

3. Backup and restore secrets:
```bash
# Backup secrets (be careful with these files)
kubectl get secret qualys-agent-credentials -n qualys-system -o yaml > qualys-secret-backup.yaml

# Restore from backup
kubectl apply -f qualys-secret-backup.yaml
```

## Security Considerations

### Secrets Management
- Kubernetes Secrets: Sensitive credentials stored separately from configuration
- Encryption at rest: Enable etcd encryption for secret data in production clusters
- RBAC controls: Limit access to secrets using role-based access controls
- Secret rotation: Regularly update Qualys credentials using the management scripts
- Audit logging: Monitor secret access through Kubernetes audit logs

### Container Security
- Container runs as privileged to install system packages
- Host filesystem is mounted for chroot installation
- Use private container registry for RPM binary
- Regularly update RPM binary for security patches
- Consider using admission controllers to enforce security policies

### Best Practices
- Never commit secrets to version control systems
- Use the secure secret management script instead of plain text YAML
- Implement secret scanning in CI/CD pipelines
- Monitor for unauthorized access to credentials
- Use service accounts with minimal required permissions

## Benefits of This Approach

This bundled approach offers several advantages over the original download-based method:

- No internet dependency during installation since the RPM is bundled in the image
- Faster deployment times without download delays during startup
- Better version control with specific agent versions tied to image tags
- Support for air-gapped environments without external network access
- Consistent deployments using the same binary across all nodes regardless of network conditions  

## Alternative Approaches

Consider these alternatives based on your specific requirements:

- For frequent agent updates, the original URL-based download method provides more flexibility
- Init containers could be used for one-time installation instead of long-running DaemonSet pods
- Kubernetes operators might be worth exploring for more sophisticated lifecycle management scenarios
