#!/bin/bash
# manage-secrets.sh - Secure management of Qualys credentials as Kubernetes secrets

set -e

NAMESPACE="qualys-system"
SECRET_NAME="qualys-agent-credentials"
CONFIGMAP_NAME="qualys-agent-config"

echo "=== Qualys Cloud Agent Secret Management ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
else
    echo "Using existing namespace: $NAMESPACE"
fi

echo ""
echo "Choose an action:"
echo "1. Create/Update Qualys credentials"
echo "2. View current configuration (non-sensitive)"
echo "3. Delete credentials"
echo "4. Test secret access"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo ""
        echo "=== Creating/Updating Qualys Credentials ==="
        echo ""
        
        echo "Please provide your Qualys Cloud Agent credentials:"
        echo ""
        
        # Gather credentials securely
        echo "1. Activation ID:"
        echo "   Find this in your Qualys console under VMDR > Downloads > Cloud Agent"
        read -s -p "   Enter Activation ID: " ACTIVATION_ID
        echo ""
        
        echo ""
        echo "2. Customer ID:"
        echo "   Find this in your Qualys console under VMDR > Downloads > Cloud Agent"
        read -s -p "   Enter Customer ID: " CUSTOMER_ID
        echo ""
        
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
        
        # Validate inputs
        if [[ -z "$ACTIVATION_ID" || -z "$CUSTOMER_ID" || -z "$SERVER_URI" ]]; then
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
        echo "Creating/updating Kubernetes secret..."
        
        # Create or update the secret
        if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "Updating existing secret: $SECRET_NAME"
            kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
        else
            echo "Creating new secret: $SECRET_NAME"
        fi
        
        kubectl create secret generic "$SECRET_NAME" \
            --namespace="$NAMESPACE" \
            --from-literal=ACTIVATION_ID="$ACTIVATION_ID" \
            --from-literal=CUSTOMER_ID="$CUSTOMER_ID"
        
        echo "Secret created successfully"
        
        # Create or update the configmap
        if kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "Updating existing configmap: $CONFIGMAP_NAME"
            kubectl delete configmap "$CONFIGMAP_NAME" -n "$NAMESPACE"
        else
            echo "Creating new configmap: $CONFIGMAP_NAME"
        fi
        
        kubectl create configmap "$CONFIGMAP_NAME" \
            --namespace="$NAMESPACE" \
            --from-literal=SERVER_URI="$SERVER_URI" \
            --from-literal=LOG_LEVEL="$LOG_LEVEL"
        
        echo "ConfigMap created successfully"
        echo ""
        echo "Configuration complete! You can now deploy the DaemonSet."
        ;;
        
    2)
        echo ""
        echo "=== Current Configuration ==="
        echo ""
        
        if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "Secret '$SECRET_NAME' exists with keys:"
            kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json | grep -o '"[^"]*":' | sed 's/[":]*//g'
        else
            echo "Secret '$SECRET_NAME' does not exist"
        fi
        
        echo ""
        
        if kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "ConfigMap '$CONFIGMAP_NAME' contains:"
            kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o yaml | grep -A 10 "data:"
        else
            echo "ConfigMap '$CONFIGMAP_NAME' does not exist"
        fi
        ;;
        
    3)
        echo ""
        echo "=== Deleting Credentials ==="
        echo ""
        
        read -p "Are you sure you want to delete all Qualys credentials? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
                kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
                echo "Secret deleted"
            else
                echo "Secret does not exist"
            fi
            
            if kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
                kubectl delete configmap "$CONFIGMAP_NAME" -n "$NAMESPACE"
                echo "ConfigMap deleted"
            else
                echo "ConfigMap does not exist"
            fi
        else
            echo "Deletion cancelled"
        fi
        ;;
        
    4)
        echo ""
        echo "=== Testing Secret Access ==="
        echo ""
        
        if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
            echo "ERROR: Secret '$SECRET_NAME' does not exist"
            exit 1
        fi
        
        echo "Testing secret access by creating a temporary pod..."
        
        kubectl run secret-test-pod \
            --namespace="$NAMESPACE" \
            --image=alpine:latest \
            --rm -i --tty \
            --restart=Never \
            --env="ACTIVATION_ID_LENGTH=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ACTIVATION_ID}' | base64 -d | wc -c)" \
            --env="CUSTOMER_ID_LENGTH=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.CUSTOMER_ID}' | base64 -d | wc -c)" \
            -- sh -c 'echo "ACTIVATION_ID length: $ACTIVATION_ID_LENGTH characters"; echo "CUSTOMER_ID length: $CUSTOMER_ID_LENGTH characters"; echo "Secret access test successful!"'
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=== Useful Commands ==="
echo ""
echo "Check DaemonSet status:"
echo "  kubectl get daemonset -n $NAMESPACE"
echo ""
echo "Check pod logs:"
echo "  kubectl logs -n $NAMESPACE -l app=qualys-cloud-agent"
echo ""
echo "Describe secret (metadata only):"
echo "  kubectl describe secret $SECRET_NAME -n $NAMESPACE"
echo ""
echo "Check if pods can access secrets:"
echo "  kubectl exec -n $NAMESPACE <pod-name> -- env | grep -E '(ACTIVATION_ID|CUSTOMER_ID)'"
