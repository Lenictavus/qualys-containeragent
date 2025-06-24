#!/bin/bash

# install.sh - Installs bundled Qualys Cloud Agent DEB or RPM package
set -e

# Configuration from environment variables (set by ConfigMap)
ACTIVATION_ID="${ACTIVATION_ID:-}"
CUSTOMER_ID="${CUSTOMER_ID:-}"
SERVER_URI="${SERVER_URI:-}"
LOG_LEVEL="${LOG_LEVEL:-3}"

# Paths
CHROOT_PATH="/host"
AGENT_CONFIG_PATH="${CHROOT_PATH}/etc/qualys/cloud-agent"

echo "Starting Qualys Cloud Agent installation..."
echo "Activation ID: ${ACTIVATION_ID}"
echo "Customer ID: ${CUSTOMER_ID}"
echo "Server URI: ${SERVER_URI}"

# Validate required environment variables
if [[ -z "$ACTIVATION_ID" || -z "$CUSTOMER_ID" || -z "$SERVER_URI" ]]; then
    echo "ERROR: Missing required environment variables (ACTIVATION_ID, CUSTOMER_ID, or SERVER_URI)"
    exit 1
fi

# Detect which package type we have
DEB_PATH="/opt/qualys/qualys-cloud-agent.deb"
RPM_PATH="/opt/qualys/qualys-cloud-agent.rpm"
PACKAGE_PATH=""
PACKAGE_TYPE=""

if [[ -f "$DEB_PATH" ]]; then
    PACKAGE_PATH="$DEB_PATH"
    PACKAGE_TYPE="deb"
    echo "Found DEB package: $DEB_PATH"
elif [[ -f "$RPM_PATH" ]]; then
    PACKAGE_PATH="$RPM_PATH"
    PACKAGE_TYPE="rpm"
    echo "Found RPM package: $RPM_PATH"
else
    echo "ERROR: No Qualys Cloud Agent package found"
    echo "Expected either qualys-cloud-agent.deb or qualys-cloud-agent.rpm in /opt/qualys/"
    exit 1
fi

# Create necessary directories on host
mkdir -p "${CHROOT_PATH}/tmp/qualys"
mkdir -p "${AGENT_CONFIG_PATH}"

# Copy package to host filesystem
cp "$PACKAGE_PATH" "${CHROOT_PATH}/tmp/qualys/"
PACKAGE_NAME=$(basename "$PACKAGE_PATH")

# Install the agent using chroot
echo "Installing Qualys Cloud Agent on host system..."

# Detect host package manager and install accordingly
if chroot "$CHROOT_PATH" bash -c "which dpkg > /dev/null 2>&1"; then
    echo "Detected Debian/Ubuntu host"
    
    if [[ "$PACKAGE_TYPE" == "deb" ]]; then
        echo "Installing DEB package..."
        chroot "$CHROOT_PATH" bash -c "
            cd /tmp/qualys
            dpkg -i $PACKAGE_NAME || apt-get install -f -y
        "
    else
        echo "ERROR: RPM package provided but host requires DEB package"
        echo "Please use qualys-cloud-agent.deb for Ubuntu/Debian hosts"
        exit 1
    fi
    
elif chroot "$CHROOT_PATH" bash -c "which rpm > /dev/null 2>&1"; then
    echo "Detected RPM-based host (RHEL/CentOS/CoreOS)"
    
    if [[ "$PACKAGE_TYPE" == "rpm" ]]; then
        echo "Installing RPM package..."
        chroot "$CHROOT_PATH" bash -c "
            cd /tmp/qualys
            rpm -ivh $PACKAGE_NAME
        "
    else
        echo "ERROR: DEB package provided but host requires RPM package"
        echo "Please use qualys-cloud-agent.rpm for RHEL/CentOS/CoreOS hosts"
        exit 1
    fi
else
    echo "ERROR: Could not detect supported package manager on host"
    echo "Host must have either dpkg (Debian/Ubuntu) or rpm (RHEL/CentOS/CoreOS)"
    exit 1
fi

# Configure the agent
echo "Configuring Qualys Cloud Agent..."

# Create configuration file
cat > "${AGENT_CONFIG_PATH}/qualys-cloud-agent.conf" << EOF
[Configuration]
ActivationId=$ACTIVATION_ID
CustomerId=$CUSTOMER_ID
ServerUri=$SERVER_URI
LogLevel=$LOG_LEVEL

[Startup]
SuppressPopup=1
RunAs=0
EOF

# Set proper permissions
chroot "$CHROOT_PATH" bash -c "
    chown -R root:root /etc/qualys
    chmod 755 /etc/qualys
    chmod 644 /etc/qualys/cloud-agent/qualys-cloud-agent.conf
"

# Start the agent service
echo "Starting Qualys Cloud Agent service..."
chroot "$CHROOT_PATH" bash -c "
    systemctl enable qualys-cloud-agent
    systemctl start qualys-cloud-agent
    systemctl status qualys-cloud-agent
"

# Cleanup
rm -rf "${CHROOT_PATH}/tmp/qualys"

echo "Qualys Cloud Agent installation completed successfully!"
echo "Agent should now be active and reporting to Qualys console."

# Keep container running to maintain DaemonSet
echo "Container will now sleep to maintain DaemonSet pod..."
sleep infinity
