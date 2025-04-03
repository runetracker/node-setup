#!/bin/bash
set -eu

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if ord.service is active
SERVICE_NAME="ord.service"
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "$SERVICE_NAME is currently active. Please stop it first with 'systemctl stop $SERVICE_NAME' before updating."
  exit 1
fi

# Check if ord exists in /usr/local/bin and remove it
if [ -f /usr/local/bin/ord ]; then
  echo "Existing ord binary found in /usr/local/bin."
  echo "Removing existing ord binary..."
  rm /usr/local/bin/ord
else
  echo "No existing ord binary found in /usr/local/bin. Nothing to update."
  exit 0
fi

# Install ord using the official script with sudo, specifying the installation location
echo "Installing latest version of ord to /usr/local/bin..."
curl --proto '=https' --tlsv1.2 -fsLS https://ordinals.com/install.sh | sudo bash -s -- --to /usr/local/bin

# Ensure ord is executable
chmod 755 /usr/local/bin/ord

# Verify installation
echo "Verifying ord installation..."
ord --version

echo "Ord update completed."
echo "You need to start the service again by running: 'sudo systemctl start ord.service'"
