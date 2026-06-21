#!/usr/bin/env bash
set -euo pipefail

NANOMDM_VERSION="v0.7.0"
INSTALL_DIR="/opt/nanomdm"
DATA_DIR="/var/lib/nanomdm"

echo "setting up nanomdm ${NANOMDM_VERSION}..."

# create dirs
sudo mkdir -p "$INSTALL_DIR" "$DATA_DIR"

# download binary
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
fi

curl -sL "https://github.com/micromdm/nanomdm/releases/download/${NANOMDM_VERSION}/nanomdm-linux-${ARCH}" \
    -o "$INSTALL_DIR/nanomdm"
sudo chmod +x "$INSTALL_DIR/nanomdm"

# create systemd service
sudo tee /etc/systemd/system/nanomdm.service > /dev/null <<EOF
[Unit]
Description=NanoMDM
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/nanomdm \\
    -listen :9002 \\
    -api nanomdm \\
    -storage file \\
    -storage-path ${DATA_DIR}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nanomdm
sudo systemctl start nanomdm

echo "nanomdm installed and running on :9002"
