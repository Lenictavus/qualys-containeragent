#!/bin/bash
# configure-agent.sh - Helper script for configuring Qualys credentials

set -e

echo "=== Qualys Cloud Agent Configuration Helper ==="
echo ""
echo "This script will help you configure the Qualys Cloud Agent credentials"
echo "in your Kubernetes DaemonSet YAML file."
echo ""
echo "NOTE: For better security, consider using manage-secrets.sh instead,"
echo "which creates Kubernetes secrets directly without storing credentials in files."
echo ""

# Check if daemonset.yaml exists
DAEMONSET_FILE="k8s/daemonset.yaml"
if [[ ! -f "$DAEMONSET_FILE" ]]; then
    echo "ERROR: $DAEMONSET_FILE not found"
    echo "Please ensure you have the DaemonSet YAML file in the correct location."
    exit 1
fi

echo "Please provide your Qualys Cloud Agent configuration:"
echo ""

# Gather configuration values
echo "1. Activation ID:"
echo "   Find this in your Qualys console under VMDR > Downloads > Cloud Agent"
read -p "   Enter Activation ID: " ACTIVATION_ID

echo ""
echo "2. Customer ID:"
echo "   Find this in your Qualys console under VMDR > Downloads > Cloud Agent"
read -p "   Enter Customer ID: " CUSTOMER_ID

echo ""
echo "3. Server URI:"
echo "   Get this from: https://www.qualys.com/platform-identification/"
echo "   Example: https://qagpublic.qg1.apps.qualys.com/CloudAgent/"
read -p "   Enter Server URI: " SERVER_URI

echo ""
echo "4. Log Level (optional):"
echo "   0=Error, 1=Warning, 2=Info, 3=Debug, 4=Verbose, 5=All"
read -p "   Enter Log Level [3]: " LOG_LEVEL
LOG_LEVEL=${LOG_LEVEL:-3}

echo ""
echo "5. Container Image:"
echo "   The full path to your built container image"
read -p "   Enter image (e.g., your-registry.com/qualys-agent-bundled:v1.0.0): " CONTAINER_IMAGE

echo ""

# Validate inputs
if [[ -z "$ACTIVATION_ID" || -z "$CUSTOMER_ID" || -z "$SERVER_URI" || -z "$CONTAINER_IMAGE" ]]; then
    echo "ERROR: All required fields must be provided"
    exit 1
fi

# Validate Server URI format
if [[ ! "$SERVER_URI" =~ ^https?:// ]]; then
    echo "ERROR: Server URI must start with http:// or https://"
    exit 1
fi

# Ensure Server URI ends with /CloudAgent/
if [[ ! "$SERVER_URI" =~ /CloudAgent/?$ ]]; then
    if [[ "$SERVER_URI" =~ /$ ]]; then
        SERVER_URI="${SERVER_URI}CloudAgent/"
    else
        SERVER_URI="${SERVER_URI}/CloudAgent/"
    fi
fi

echo ""
echo "Configuration Summary:"
echo "Activation ID: $ACTIVATION_ID"
echo "Customer ID: $CUSTOMER_ID"
echo "Server URI: $SERVER_URI"
echo "Log Level: $LOG_LEVEL"
echo "Container Image: $CONTAINER_IMAGE"
echo ""

read -p "Is this configuration correct? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Configuration cancelled."
    exit 0
fi

echo ""
echo "Updating $DAEMONSET_FILE..."

echo ""
echo "Updating $DAEMONSET_FILE..."

# Create backup
cp "$DAEMONSET_FILE" "${DAEMONSET_FILE}.backup"
echo "Backup created: ${DAEMONSET_FILE}.backup"

# Update the YAML file using sed
sed -i.tmp \
    -e "s/YOUR_ACTIVATION_ID_HERE/$ACTIVATION_ID/g" \
    -e "s/YOUR_CUSTOMER_ID_HERE/$CUSTOMER_ID/g" \
    -e "s|https://YOUR_QUALYS_SERVER/CloudAgent/|$SERVER_URI|g" \
    -e "s/your-registry\/qualys-agent-bundled:latest/$CONTAINER_IMAGE/g" \
    -e "s/LOG_LEVEL: \"3\"/LOG_LEVEL: \"$LOG_LEVEL\"/g" \
    "$DAEMONSET_FILE"

# Remove temporary file
rm -f "${DAEMONSET_FILE}.tmp"

echo "Configuration updated in $DAEMONSET_FILE"
echo ""

# Show what was changed
echo "=== Configuration Applied ==="
echo ""
echo "Secret (qualys-agent-credentials) updated with:"
echo "  ACTIVATION_ID: \"$ACTIVATION_ID\""
echo "  CUSTOMER_ID: \"$CUSTOMER_ID\""
echo ""
echo "ConfigMap (qualys-agent-config) updated with:"
echo "  SERVER_URI: \"$SERVER_URI\""
echo "  LOG_LEVEL: \"$LOG_LEVEL\""
echo ""
echo "Container image updated to:"
echo "  image: $CONTAINER_IMAGE"
echo ""

echo "=== Next Steps ==="
echo ""
echo "1. Review the updated configuration:"
echo "   cat $DAEMONSET_FILE"
echo ""
echo "2. Deploy to your Kubernetes cluster:"
echo "   kubectl apply -f $DAEMONSET_FILE"
echo ""
echo "3. Verify secrets are properly created:"
echo "   kubectl get secret qualys-agent-credentials -n qualys-system"
echo "   kubectl get configmap qualys-agent-config -n qualys-system"
echo ""
echo "4. Monitor the deployment:"
echo "   kubectl get daemonset -n qualys-system"
echo "   kubectl get pods -n qualys-system"
echo ""
echo "5. Check agent logs:"
echo "   kubectl logs -n qualys-system -l app=qualys-cloud-agent"
echo ""

echo "Configuration complete!"
