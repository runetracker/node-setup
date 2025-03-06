#!/bin/bash
set -eu

# Check for root privileges
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Check if /data is mounted
if ! mount | grep -q /data; then
    echo "/data is not mounted. Please mount your SSD to /data first."
    exit 1
fi

# Function to check disk space
check_disk_space() {
    local required_space=$1
    local free_space=$(df -BG /data | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$free_space" -lt "$required_space" ]; then
        echo "Not enough free space on /data. At least ${required_space}GB is required for this blockchain."
        exit 1
    fi
}

# Function to clean up temporary files
cleanup_temp_files() {
    local tarball=$1
    local extracted_dir=$2

    cd /tmp
    if [ -f "$tarball" ]; then
        rm "$tarball"
    fi
    if [ -d "$extracted_dir" ]; then
        rm -rf "$extracted_dir"
    fi
}

# Function to setup a blockchain node with dedicated user/group
setup_node() {
    local blockchain=$1
    local url=$2
    local min_space=$3
    local tarball
    local extracted_dir
    local conf_file="${blockchain}.conf"
    local daemon="${blockchain}d"
    # Default configuration options for building
    local configure_options="--prefix=/usr --disable-bench --disable-gui --with-incompatible-bdb"

    # Extract tarball name from URL
    tarball=$(basename "$url")

    # Check disk space for this blockchain
    check_disk_space $min_space

    # Create blockchain specific user and group
    if ! getent passwd "$blockchain" > /dev/null 2>&1; then
        adduser --system --group --home /data/$blockchain $blockchain
    else
        echo "User '$blockchain' already exists. Skipping user creation."
    fi

    # Create blockchain specific directory with correct permissions
    mkdir -p /data/$blockchain
    chown $blockchain:$blockchain /data/$blockchain

    # Update system and install dependencies
    apt update && apt upgrade -y
    apt install -y build-essential cmake pkgconf python3 libevent-dev libboost-dev

    # Fetch source code
    cd /tmp
    wget $url
    tar -xzvf "$tarball"
    # Assuming the folder name starts with blockchain name, followed by a dash and version
    extracted_dir=$(ls -d /tmp/${blockchain}-* | head -n 1)

    if [ -d "$extracted_dir" ]; then
        cd "$extracted_dir"
    else
        echo "Error: Could not find extracted directory for $blockchain."
        cleanup_temp_files "$tarball" "/tmp/${blockchain}-*"  # Cleanup even if the exact dir isn't found
        exit 1
    fi

    # Configure and build the software
    if [ -f autogen.sh ]; then
        ./autogen.sh
    else
        echo "Error: autogen script not found in $(pwd)"
        cleanup_temp_files "$tarball" "$extracted_dir"
        exit 1
    fi

    if [ -f configure ]; then
        ./configure $configure_options
    else
        echo "Error: configure script not found in $(pwd)"
        cleanup_temp_files "$tarball" "$extracted_dir"
        exit 1
    fi

    make -j$(nproc)
    make check
    make install

    # Create configuration file
    cat << EOF > /data/$blockchain/$conf_file
datadir=/data/$blockchain
server=1
txindex=1
rpcuser=myuser
rpcpassword=mypassword
EOF
    chown $blockchain:$blockchain /data/$blockchain/$conf_file
    chmod 600 /data/$blockchain/$conf_file  # Restrict to owner only for security

    # Create service for the blockchain node with dedicated user/group
    cat << EOF > /etc/systemd/system/${daemon}.service
[Unit]
Description=${blockchain}'s distributed currency daemon
After=network.target

[Service]
User=$blockchain
Group=$blockchain
Type=forking
PIDFile=/data/$blockchain/${daemon}.pid
ExecStart=/usr/bin/${daemon} -daemon -pid=/data/$blockchain/${daemon}.pid \\
-conf=/data/$blockchain/$conf_file -datadir=/data/$blockchain
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd daemon
    systemctl daemon-reload

    # Enable and start the service
    systemctl enable ${daemon}
    systemctl start ${daemon}

    echo "$blockchain node setup completed. Check status with 'systemctl status ${daemon}'"
    
    # Cleanup
    cleanup_temp_files "$tarball" "$extracted_dir"
}

setup_node "bitcoin" "https://bitcoincore.org/bin/bitcoin-core-28.1/bitcoin-28.1.tar.gz" 1000
