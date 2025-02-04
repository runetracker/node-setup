#!/bin/bash
set -eu

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install ord using the official script
echo "Installing ord..."
curl --proto '=https' --tlsv1.2 -fsLS https://ordinals.com/install.sh | bash -s

# Move ord to /usr/local/bin if not already there for system-wide access
if ! command -v ord &> /dev/null; then
  echo "Moving ord to /usr/local/bin..."
  mv /root/.cargo/bin/ord /usr/local/bin/ord
fi

# Ensure ord is executable
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

# Verify installation
echo "Verifying ord installation..."
ord --version

# Show current configuration settings
echo "Current ord settings:"
ord settings

echo "Ord installation and configuration completed."
