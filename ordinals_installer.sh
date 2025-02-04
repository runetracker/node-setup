#!/bin/bash
set -eu

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if ord already exists in /usr/local/bin and remove it if it does
if [ -f /usr/local/bin/ord ]; then
  echo "Existing ord binary found in /usr/local/bin. Removing it..."
  rm /usr/local/bin/ord
fi

# Install ord using the official script with sudo, specifying the installation location
echo "Installing ord to /usr/local/bin..."
curl --proto '=https' --tlsv1.2 -fsLS https://ordinals.com/install.sh | sudo bash -s -- --to /usr/local/bin

# Ensure ord is executable (though it should be by default)
chmod 755 /usr/local/bin/ord

# Create and set permissions for data directory on SSD
echo "Setting up ord data directory on SSD..."
DATA_DIR="/data/ord"
mkdir -p "$DATA_DIR"
chown -R bitcoin:bitcoin "$DATA_DIR"
chmod -R 750 "$DATA_DIR"

# Write configuration file
echo "Configuring ord with ord.yaml..."
cat << EOF > "$DATA_DIR/ord.yaml"
# Configuration for ord
bitcoin_data_dir: /data/bitcoin
cookie_file: /data/bitcoin/.cookie
data_dir: $DATA_DIR
index: $DATA_DIR/index.redb
index_addresses: true
index_runes: true
index_sats: true
index_transactions: true
EOF

# Check if ORD_DATA_DIR exists in /etc/environment
if grep -q "^ORD_DATA_DIR=" /etc/environment; then
  echo "ORD_DATA_DIR is already set in /etc/environment."
else
  # Set environment variable for ord to use the new data directory
  echo "Setting ORD_DATA_DIR environment variable..."
  echo 'ORD_DATA_DIR="'$DATA_DIR'"' >> /etc/environment
fi

# Export ORD_DATA_DIR for the current shell session
export ORD_DATA_DIR="$DATA_DIR"

# Verify installation
echo "Verifying ord installation..."
ord --version

# Show current configuration settings
echo "Current ord settings:"
ord settings

echo "Ord installation and configuration completed."
