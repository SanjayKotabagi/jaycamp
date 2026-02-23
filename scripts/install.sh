#!/bin/bash
# =============================================================================
# JayCamp Installer
# Raspberry Pi Zero 2 W — Offline Knowledge & File Station
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORTAL_DIR="/home/pi/portal"
LIBRARY_DIR="/home/pi/library"

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║        JayCamp Installer v1.0        ║"
echo "  ║   Offline Knowledge & File Station   ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ── CHECK ROOT ───────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root: sudo ./scripts/install.sh${NC}"
  exit 1
fi

# ── STEP 1: UPDATE & INSTALL PACKAGES ────────────────────────
echo -e "${YELLOW}[1/8] Installing packages...${NC}"
apt update -qq
apt install -y nginx python3-pip dnsmasq wget curl git exfat-fuse exfat-utils ntfs-3g 2>/dev/null || true
pip3 install flask flask-cors --break-system-packages -q

# ── STEP 2: INSTALL KIWIX ────────────────────────────────────
echo -e "${YELLOW}[2/8] Installing Kiwix...${NC}"
if ! command -v kiwix-serve &>/dev/null; then
  KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-armhf.tar.gz"
  wget -q --show-progress -O /tmp/kiwix.tar.gz "$KIWIX_URL"
  tar -xzf /tmp/kiwix.tar.gz -C /tmp/
  KIWIX_DIR=$(find /tmp -maxdepth 1 -name "kiwix-tools_linux-armhf*" -type d | head -1)
  mv "$KIWIX_DIR" /opt/kiwix
  ln -sf /opt/kiwix/kiwix-serve /usr/local/bin/kiwix-serve
  ln -sf /opt/kiwix/kiwix-manage /usr/local/bin/kiwix-manage
  rm /tmp/kiwix.tar.gz
  echo -e "${GREEN}  Kiwix installed.${NC}"
else
  echo -e "${GREEN}  Kiwix already installed, skipping.${NC}"
fi

# ── STEP 3: CREATE DIRECTORIES ───────────────────────────────
echo -e "${YELLOW}[3/8] Creating directories...${NC}"
mkdir -p "$PORTAL_DIR" "$LIBRARY_DIR" /mnt/usb1 /mnt/usb2
chmod 755 "$PORTAL_DIR" "$LIBRARY_DIR"
chown -R pi:pi "$PORTAL_DIR" "$LIBRARY_DIR"

# Create empty library.xml if none exists
if [ ! -f "$LIBRARY_DIR/library.xml" ]; then
  echo '<?xml version="1.0" encoding="UTF-8"?><library version="1.0"></library>' > "$LIBRARY_DIR/library.xml"
  chown pi:pi "$LIBRARY_DIR/library.xml"
fi

# ── STEP 4: COPY PORTAL FILES ────────────────────────────────
echo -e "${YELLOW}[4/8] Deploying portal files...${NC}"
cp "$REPO_DIR/portal/index.html" "$PORTAL_DIR/index.html"
cp "$REPO_DIR/portal/files.html" "$PORTAL_DIR/files.html"
cp "$REPO_DIR/depot_server.py" /home/pi/depot_server.py
chmod 644 "$PORTAL_DIR"/*
chown pi:pi "$PORTAL_DIR"/* /home/pi/depot_server.py
chmod 755 /home/pi
echo -e "${GREEN}  Portal files deployed.${NC}"

# ── STEP 5: CONFIGURE NGINX ──────────────────────────────────
echo -e "${YELLOW}[5/8] Configuring Nginx...${NC}"
cp "$REPO_DIR/nginx/basecamp.conf" /etc/nginx/sites-available/basecamp
ln -sf /etc/nginx/sites-available/basecamp /etc/nginx/sites-enabled/basecamp
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx || systemctl start nginx
systemctl enable nginx
echo -e "${GREEN}  Nginx configured.${NC}"

# ── STEP 6: SETUP WIFI HOTSPOT ───────────────────────────────
echo -e "${YELLOW}[6/8] Setting up WiFi hotspot...${NC}"

# Ask for hotspot password
read -p "  Enter hotspot password (min 8 chars): " HOTSPOT_PASS
while [ ${#HOTSPOT_PASS} -lt 8 ]; do
  echo -e "${RED}  Password too short. Min 8 characters.${NC}"
  read -p "  Enter hotspot password: " HOTSPOT_PASS
done

# Setup dnsmasq
cat > /etc/dnsmasq.conf << EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/jaycamp.local/192.168.4.1
EOF
systemctl enable dnsmasq
systemctl restart dnsmasq

# Create hotspot via NetworkManager
nmcli connection delete "jaycamp-hotspot" 2>/dev/null || true
nmcli connection add \
  type wifi ifname wlan0 con-name jaycamp-hotspot autoconnect yes ssid JayCamp \
  -- wifi.mode ap wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$HOTSPOT_PASS" \
  ipv4.method shared ipv4.addresses 192.168.4.1/24
nmcli connection up jaycamp-hotspot
echo -e "${GREEN}  Hotspot 'JayCamp' created with your password.${NC}"

# ── STEP 7: INSTALL SYSTEMD SERVICES ─────────────────────────
echo -e "${YELLOW}[7/8] Installing systemd services...${NC}"
cp "$REPO_DIR/systemd/kiwix.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/depot.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/usb-mount@.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/usb-unmount@.service" /etc/systemd/system/

# USB udev rule
cp "$REPO_DIR/scripts/99-usb-automount.rules" /etc/udev/rules.d/
udevadm control --reload-rules

systemctl daemon-reload
systemctl enable kiwix depot
systemctl start kiwix depot
echo -e "${GREEN}  Services installed and started.${NC}"

# ── STEP 8: DONE ─────────────────────────────────────────────
echo -e "${YELLOW}[8/8] Finalising...${NC}"
chown -R pi:pi /home/pi

echo ""
echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║           Installation Complete!                 ║"
echo "  ╠══════════════════════════════════════════════════╣"
echo "  ║  WiFi Name : JayCamp                            ║"
echo "  ║  Password  : $HOTSPOT_PASS"
echo "  ║                                                  ║"
echo "  ║  BASE CAMP : http://192.168.4.1                 ║"
echo "  ║  DEPOT     : http://192.168.4.1:81              ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Next: Add ZIM files with: sudo ./scripts/add-zim.sh"
echo "  Then reboot: sudo reboot"
echo ""
