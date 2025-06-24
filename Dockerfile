# Dockerfile for bundling Qualys Cloud Agent DEB or RPM package
FROM ubuntu:22.04

# Install required packages for installation and runtime
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg2 \
    software-properties-common \
    systemctl \
    kmod \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create directory for Qualys agent
RUN mkdir -p /opt/qualys

# Copy the package into the image - can be either DEB or RPM
# Place either qualys-cloud-agent.deb or qualys-cloud-agent.rpm in your build context
COPY qualys-cloud-agent.* /opt/qualys/

# Copy installation and configuration scripts
COPY install.sh /opt/qualys/
COPY configure-agent.sh /opt/qualys/

# Make scripts executable
RUN chmod +x /opt/qualys/install.sh /opt/qualys/configure-agent.sh

# Set working directory
WORKDIR /opt/qualys

# Default command - run the installation script
CMD ["/opt/qualys/install.sh"]
