#!/bin/bash
# build.sh - Build script for Qualys Cloud Agent bundled container (DEB or RPM)

set -e

# Configuration - UPDATE THESE VALUES
REGISTRY="your-registry.com"  # Replace with your container registry
IMAGE_NAME="qualys-agent-bundled"
TAG="v1.0.0"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "=== Qualys Cloud Agent Container Builder ==="
echo "Image: ${FULL_IMAGE}"
echo ""

# Verify prerequisites
echo "Checking prerequisites..."

# Check if Docker/Podman is available
if command -v docker &> /dev/null; then
    CONTAINER_TOOL="docker"
    echo "Found Docker"
elif command -v podman &> /dev/null; then
    CONTAINER_TOOL="podman"
    echo "Found Podman"
else
    echo "ERROR: Neither Docker nor Podman found. Please install one of them."
    exit 1
fi

# Verify required files exist
echo "Checking required files..."

if [[ ! -f "Dockerfile" ]]; then
    echo "ERROR: Dockerfile not found in current directory"
    exit 1
fi
echo "Dockerfile found"

if [[ ! -f "install.sh" ]]; then
    echo "ERROR: install.sh not found in current directory"
    exit 1
fi
echo "install.sh found"

if [[ ! -f "qualys-cloud-agent.deb" && ! -f "qualys-cloud-agent.rpm" ]]; then
    echo "ERROR: No Qualys Cloud Agent package found in current directory"
    echo "Please download the appropriate package from your Qualys console and place it here"
    echo "Expected files:"
    echo "  - qualys-cloud-agent.deb (for Ubuntu/Debian hosts)"
    echo "  - qualys-cloud-agent.rpm (for RHEL/CentOS hosts)"
    echo ""
    echo "Steps:"
    echo "1. Log into Qualys VMDR console"
    echo "2. Go to Help > Downloads > Cloud Agent"
    echo "3. Download Linux x86_64 DEB or RPM package"
    echo "4. Rename to 'qualys-cloud-agent.deb' or 'qualys-cloud-agent.rpm' and place in this directory"
    exit 1
fi

if [[ -f "qualys-cloud-agent.deb" ]]; then
    echo "qualys-cloud-agent.deb found"
    PACKAGE_SIZE=$(du -h "qualys-cloud-agent.deb" | cut -f1)
    echo "  DEB package size: ${PACKAGE_SIZE}"
fi

if [[ -f "qualys-cloud-agent.rpm" ]]; then
    echo "qualys-cloud-agent.rpm found"
    PACKAGE_SIZE=$(du -h "qualys-cloud-agent.rpm" | cut -f1)
    echo "  RPM package size: ${PACKAGE_SIZE}"
fi

echo ""

# Build the container image
echo "Building container image..."
echo "This may take a few minutes..."

$CONTAINER_TOOL build \
    --tag "${FULL_IMAGE}" \
    --tag "${REGISTRY}/${IMAGE_NAME}:latest" \
    .

if [[ $? -eq 0 ]]; then
    echo "Build completed successfully!"
else
    echo "Build failed"
    exit 1
fi

echo ""

# Show image information
echo "Image information:"
$CONTAINER_TOOL images | grep "${IMAGE_NAME}" | head -5

echo ""

# Next steps
echo "=== Next Steps ==="
echo ""
echo "1. Push to registry:"
echo "   ${CONTAINER_TOOL} push ${FULL_IMAGE}"
echo ""
echo "2. Update k8s/daemonset.yaml with this image:"
echo "   image: ${FULL_IMAGE}"
echo ""
echo "3. Configure your Qualys credentials in the ConfigMap:"
echo "   - ACTIVATION_ID"
echo "   - CUSTOMER_ID" 
echo "   - SERVER_URI"
echo ""
echo "4. Deploy to Kubernetes:"
echo "   kubectl apply -f k8s/daemonset.yaml"
echo ""

# Optional: Ask if user wants to push now
read -p "Do you want to push the image to the registry now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Pushing image to registry..."
    $CONTAINER_TOOL push "${FULL_IMAGE}"
    $CONTAINER_TOOL push "${REGISTRY}/${IMAGE_NAME}:latest"
    echo "Push completed!"
else
    echo "Skipping push. You can push later with:"
    echo "${CONTAINER_TOOL} push ${FULL_IMAGE}"
fi

echo ""
echo "Build process complete!"
