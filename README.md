# Qualys Cloud Agent for Kubernetes - Bundled Package Approach

This solution deploys Qualys Cloud Agent across Kubernetes worker nodes using a DaemonSet with the agent package bundled directly into the container image.

## Problem solved

The original Qualys k8s-daemonset downloads agent binaries from URLs during pod startup, which causes network timeouts, inconsistent deployments, and doesn't work in air-gapped environments. This approach bundles the DEB or RPM package into the container image for predictable deployments without runtime download dependencies.

## How it works

The container image includes either a Qualys DEB or RPM package. The DaemonSet pod mounts the host filesystem and uses chroot to install the agent directly onto the host system. The agent runs as a native systemd service.

Installation logic:
- Ubuntu/Debian + DEB package: installs directly using dpkg
- Ubuntu/Debian + RPM package: converts using alien then installs  
- RHEL/CentOS + RPM package: installs directly using rpm
- RHEL/CentOS + DEB package: not supported

## Requirements

- Kubernetes cluster with Ubuntu worker nodes
- Docker or Podman for building images  
- Container registry access
- Qualys Cloud Agent DEB or RPM package
- Qualys credentials (Activation ID, Customer ID, Server URI)

## Setup

Create a working directory:

```bash
mkdir qualys-k8s-bundled
cd qualys-k8s-bundled
```

Download the Qualys Cloud Agent package from your console (VMDR > Downloads > Cloud Agent):
- Linux x86_64 DEB package (recommended for Ubuntu) - rename to `qualys-cloud-agent.deb`
- Linux x86_64 RPM package - rename to `qualys-cloud-agent.rpm`

Your directory should look like this:
```
qualys-k8s-bundled/
├── Dockerfile
├── install.sh
├── configure-agent.sh
├── manage-secrets.sh
├── qualys-cloud-agent.deb  (or .rpm)
├── k8s/
│   └── daemonset.yaml
└── build.sh
```

Make the scripts executable:
```bash
chmod +x build.sh configure-agent.sh manage-secrets.sh install.sh
```

## Building the container

Edit `build.sh` and update the registry details for your environment:

```bash
REGISTRY="your-registry.com" 
IMAGE_NAME="qualys-agent-bundled"
TAG="v1.0.0"
```

Then build and push:

```bash
./build.sh
```

The script will detect whether you have a DEB or RPM package and show the size. It'll prompt if you want to push immediately, or you can push later manually.

## Credentials setup

Use Kubernetes secrets for sensitive credentials (Activation ID, Customer ID) and ConfigMaps for configuration.

Use the secret management script:

```bash
./manage-secrets.sh
```

Choose option 1 to create secrets securely without displaying credentials on screen.

Manual creation:

```bash
kubectl create namespace qualys-system

kubectl create secret generic qualys-agent-credentials \
  --namespace=qualys-system \
  --from-literal=ACTIVATION_ID="your-activation-id" \
  --from-literal=CUSTOMER_ID="your-customer-id"

kubectl create configmap qualys-agent-config \
  --namespace=qualys-system \
  --from-literal=SERVER_URI="https://your-qualys-server/CloudAgent/" \
  --from-literal=LOG_LEVEL="3"
```

Get your Server URI from the Qualys platform identification page.

## Deploying to Kubernetes

Update the image reference in `k8s/daemonset.yaml` to match what you built, then deploy:

```bash
kubectl apply -f k8s/daemonset.yaml
```

Check that everything's running:

```bash
kubectl get daemonset -n qualys-system
kubectl get pods -n qualys-system -o wide
```

You should see one pod per node. Check the logs if anything looks wrong:

```bash
kubectl logs -n qualys-system -l app=qualys-cloud-agent
```

## Verification

Check agent status on hosts:

```bash
kubectl exec -n qualys-system qualys-cloud-agent-xxxxx -- \
  chroot /host systemctl status qualys-cloud-agent
```

Verify environment variables:

```bash
kubectl exec -n qualys-system qualys-cloud-agent-xxxxx -- \
  env | grep -E "(ACTIVATION_ID|CUSTOMER_ID|SERVER_URI)"
```

## Common issues

**Pods stuck in pending**: Check node resources and ensure `kubernetes.io/os: linux` nodes exist.

**Permission denied**: Container needs privileged mode to install packages on host.

**Installation failures**: For RPM on Ubuntu, script installs `alien` to convert packages. Use DEB package for cleaner installation on Ubuntu.

**Agent not starting**: Check systemd logs on host. Usually credential or network connectivity issues.

**Secret access problems**: Use `./manage-secrets.sh` option 4 to test secret access.

**Package format errors**: Ensure file is named `qualys-cloud-agent.deb` or `qualys-cloud-agent.rpm`.

## Updating and maintenance

When Qualys releases a new agent version, just replace the package file, bump the version in `build.sh`, and rebuild:

```bash
./build.sh
kubectl apply -f k8s/daemonset.yaml
```

To rotate credentials without rebuilding the image:

```bash
./manage-secrets.sh
```

Choose option 1 to update the credentials, then restart the DaemonSet:

```bash
kubectl rollout restart daemonset qualys-cloud-agent -n qualys-system
```

## Benefits

Compared to the download-based method:

- No network dependencies during installation
- Faster startup times
- Consistent deployments across environments  
- Works in air-gapped environments
- Better version control with specific agent versions per image
- Native package handling (DEB for Ubuntu, RPM for RHEL)

## Security notes

The container runs privileged and mounts the host filesystem - this is necessary to install system packages. In production, make sure you:

- Use a private registry for the container image
- Enable encryption at rest for your Kubernetes secrets
- Set up RBAC to limit who can access the qualys-system namespace
- Monitor for unauthorized changes to the DaemonSet
- Keep the agent package updated for security patches

The secret management approach keeps credentials out of YAML files and version control, which is much safer than the hardcoded approach.

## Troubleshooting

Check pod events:
```bash
kubectl describe pods -n qualys-system
```

Debug installation issues:
```bash
kubectl exec -it -n qualys-system qualys-cloud-agent-xxxxx -- /bin/bash
```

Check installation logs in pod logs. To reset completely:
```bash
kubectl delete namespace qualys-system
# Then redeploy
```
