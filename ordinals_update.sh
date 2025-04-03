#!/bin/bash
set -eu

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if ord exists in /usr/local/bin
if [ -f /usr/local/bin/ord ]; then
  echo "Existing ord binary found in /usr/local/bin. Removing it..."
  rm /usr/local/bin/ord
else
  echo "No existing ord binary found in /usr/local/bin. Nothing to update."
  exit 0
fi

# Install ord using the official script with sudo, specifying the installation location
echo "Installing latest version of ord to /usr/local/bin..."
curl --proto '=https' --tlsv1.2 -fsLS https://ordinals.com/install.sh | sudo bash -s -- --to /usr/local/bin

# Ensure ord is executable (though it should be by default)
chmod 755 /usr/local/bin/ord

# Verify installation
echo "Verifying ord installation..."
ord --version

echo "Ord update completed."
