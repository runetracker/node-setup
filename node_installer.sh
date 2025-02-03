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

# Function to setup a blockchain node with dedicated user/group
setup_node() {
    local blockchain=$1
    local url=$2
    local tarball=$3
    local configure_options=$4
    local daemon=$5
    local conf_file=$6
    local min_space=$7

    # Check disk space for this blockchain
    check_disk_space $min_space

    # Create blockchain specific user and group
    adduser --system --group --home /data/$blockchain $blockchain

    # Create blockchain specific directory with correct permissions
    mkdir -p /data/$blockchain
    chown $blockchain:$blockchain /data/$blockchain

    # Update system and install dependencies
    apt update && apt upgrade -y
    apt install -y build-essential cmake pkgconf python3 libevent-dev libboost-dev

    # Fetch source code
    cd /tmp
    wget $url
    tar -xzvf $tarball
    cd $(basename $tarball .tar.gz)

    # Configure and build the software
    if [ -f autogen.sh ]; then
        ./autogen.sh
    fi
    ./configure $configure_options
    make -j$(nproc)
    make check
    make install

    # Create configuration file
    cat << EOF > /data/$blockchain/$conf_file
datadir=/data/$blockchain
rpcuser=${blockchain}rpc
rpcpassword=$(openssl rand -base64 32)
server=1
txindex=1
EOF
    chown $blockchain:$blockchain /data/$blockchain/$conf_file

    # Create service for the blockchain node with dedicated user/group
    cat << EOF > /etc/systemd/system/${daemon}d.service
[Unit]
Description=${blockchain} daemon
After=network.target

[Service]
User=$blockchain
Group=$blockchain
ExecStart=/usr/bin/${daemon}d -daemon -conf=/data/$blockchain/$conf_file -datadir=/data/$blockchain
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    systemctl enable ${daemon}d
    systemctl start ${daemon}d

    echo "$blockchain node setup completed. Check status with 'systemctl status ${daemon}d'"
}

# Example for Bitcoin with updated source URL
setup_node "bitcoin" "https://bitcoincore.org/bin/bitcoin-core-28.1/bitcoin-28.1.tar.gz" "bitcoin-28.1.tar.gz" "--prefix=/usr --disable-bench --disable-gui --with-incompatible-bdb" "bitcoind" "bitcoin.conf" 1000
