#!/bin/bash
# setup-qualys.sh - Simple setup script for Qualys Cloud Agent credentials

set -e

echo "=== Qualys Cloud Agent Setup ==="
echo ""
echo "This script will configure your Qualys credentials for the Kubernetes deployment."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    echo "Please install kubectl and ensure you can access your cluster"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    echo "Please ensure kubectl is configured and you have cluster access"
    exit 1
fi

echo "Connected to cluster: $(kubectl config current-context)"
echo ""

# Gather credentials
echo "Please provide your Qualys Cloud Agent credentials."
echo "You can find these in your Qualys console"
echo ""

echo "1. Activation ID:"
read -p "   Enter your Activation ID: " ACTIVATION_ID

echo ""
echo "2. Customer ID:"
read -p "   Enter your Customer ID: " CUSTOMER_ID

echo ""
echo "3. Server URI:"
echo "   Get this from: https://www.qualys.com/platform-identification/"
echo "   Example: https://qagpublic.qg1.apps.qualys.com/CloudAgent/"
read -p "   Enter your Server URI: " SERVER_URI

echo ""
echo "4. Log Level (optional):"
echo "   0=Error, 1=Warning, 2=Info, 3=Debug (default), 4=Verbose, 5=All"
read -p "   Enter Log Level [3]: " LOG_LEVEL
LOG_LEVEL=${LOG_LEVEL:-3}

# Validate inputs
if [[ -z "$ACTIVATION_ID" || -z "$CUSTOMER_ID" || -z "$SERVER_URI" ]]; then
    echo ""
    echo "ERROR: All required fields must be provided"
    exit 1
fi

# Validate Server URI format
if [[ ! "$SERVER_URI" =~ ^https?:// ]]; then
    echo ""
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
echo "  Activation ID: $ACTIVATION_ID"
echo "  Customer ID: $CUSTOMER_ID"
echo "  Server URI: $SERVER_URI"
echo "  Log Level: $LOG_LEVEL"
echo ""

read -p "Is this configuration correct? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "Creating Kubernetes resources..."

# Create namespace
kubectl create namespace qualys --dry-run=client -o yaml | kubectl apply -f -
echo "Namespace 'qualys' ready"

# Create or update secret
if kubectl get secret qualys-agent-credentials -n qualys >/dev/null 2>&1; then
    echo "Updating existing secret..."
    kubectl delete secret qualys-agent-credentials -n qualys
fi

kubectl create secret generic qualys-agent-credentials \
    --namespace=qualys \
    --from-literal=ACTIVATION_ID="$ACTIVATION_ID" \
    --from-literal=CUSTOMER_ID="$CUSTOMER_ID"

echo "Secret 'qualys-agent-credentials' created"

# Create or update configmap
if kubectl get configmap qualys-agent-config -n qualys >/dev/null 2>&1; then
    echo "Updating existing configmap..."
    kubectl delete configmap qualys-agent-config -n qualys
fi

kubectl create configmap qualys-agent-config \
    --namespace=qualys \
    --from-literal=SERVER_URI="$SERVER_URI" \
    --from-literal=LOG_LEVEL="$LOG_LEVEL"

echo "ConfigMap 'qualys-agent-config' created"

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Deploy the agent: kubectl apply -f qualys-daemonset.yaml"
echo "2. Check status: kubectl get pods -n qualys"
echo "3. View logs: kubectl logs -n qualys -l app=qualys-cloud-agent"
echo ""
echo "The agent will automatically detect your OS and architecture,"
echo "install the appropriate Qualys package, and start reporting to your console."
