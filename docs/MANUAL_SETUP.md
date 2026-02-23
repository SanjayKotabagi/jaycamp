# Manual Setup Guide

This guide walks through setting up JayCamp step by step without the installer script. Useful if you want to understand what's happening or customise the setup.

---

## Requirements

- Raspberry Pi Zero 2 W
- Raspberry Pi OS Lite 32-bit (Bookworm) flashed to SD card
- SSH access to the Pi
- Internet connection on the Pi for initial setup

---

## Part 1 — Flash & First Boot

1. Download [Raspberry Pi Imager](https://raspberrypi.com/software)
2. Select: **Raspberry Pi OS Lite (32-bit)** under "Raspberry Pi OS (other)"
3. Click ⚙️ settings before flashing:
   - Hostname: `basecamp`
   - Enable SSH ✓
   - Username: `pi`, set a password
   - Add your home WiFi credentials
4. Flash to SD card, insert into Pi, power on
5. Wait 90 seconds, then SSH in:

```bash
ssh pi@basecamp.local
```

---

## Part 2 — Install Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx python3-pip dnsmasq wget curl git exfat-fuse exfat-utils ntfs-3g
pip3 install flask flask-cors --break-system-packages
```

---

## Part 3 — Install Kiwix

```bash
wget https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-armhf.tar.gz
tar -xzf kiwix-tools_linux-armhf.tar.gz
sudo mv kiwix-tools_linux-armhf /opt/kiwix
sudo ln -s /opt/kiwix/kiwix-serve /usr/local/bin/kiwix-serve
sudo ln -s /opt/kiwix/kiwix-manage /usr/local/bin/kiwix-manage
```

---

## Part 4 — WiFi Hotspot

```bash
# Create hotspot (replace YOURPASSWORD)
sudo nmcli connection add \
  type wifi ifname wlan0 con-name jaycamp-hotspot autoconnect yes ssid JayCamp \
  -- wifi.mode ap wifi-sec.key-mgmt wpa-psk wifi-sec.psk "YOURPASSWORD" \
  ipv4.method shared ipv4.addresses 192.168.4.1/24

sudo nmcli connection up jaycamp-hotspot
```

Configure dnsmasq for reliable DHCP:

```bash
sudo tee /etc/dnsmasq.conf << 'EOF'
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/jaycamp.local/192.168.4.1
EOF

sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl restart NetworkManager
sudo nmcli connection up jaycamp-hotspot
```

---

## Part 5 — Deploy Portal Files

```bash
mkdir -p /home/pi/portal /home/pi/library
chmod 755 /home/pi /home/pi/portal

# Copy files from repo
cp portal/index.html /home/pi/portal/
cp portal/files.html /home/pi/portal/
cp depot_server.py /home/pi/
chmod 644 /home/pi/portal/*
```

---

## Part 6 — Configure Nginx

```bash
sudo cp nginx/basecamp.conf /etc/nginx/sites-available/basecamp
sudo ln -sf /etc/nginx/sites-available/basecamp /etc/nginx/sites-enabled/basecamp
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl reload nginx
```

---

## Part 7 — Add ZIM Files

Download ZIM files on your computer from [library.kiwix.org](https://library.kiwix.org).

Copy via SCP:
```bash
scp yourfile.zim pi@basecamp.local:/home/pi/library/
```

Or copy from USB drive on the Pi:
```bash
sudo mkdir -p /mnt/usb && sudo mount /dev/sda1 /mnt/usb
cp /mnt/usb/*.zim /home/pi/library/
```

Index the library:
```bash
kiwix-manage /home/pi/library/library.xml add /home/pi/library/*.zim
```

For each ZIM file, add a location block to `/etc/nginx/sites-available/basecamp`:
```nginx
location /your_zim_name_here {
    proxy_pass http://127.0.0.1:8080;
}
```

Then: `sudo systemctl reload nginx`

---

## Part 8 — Install Services

```bash
sudo cp systemd/kiwix.service /etc/systemd/system/
sudo cp systemd/depot.service /etc/systemd/system/
sudo cp systemd/usb-mount@.service /etc/systemd/system/
sudo cp systemd/usb-unmount@.service /etc/systemd/system/
sudo cp scripts/99-usb-automount.rules /etc/udev/rules.d/

sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo systemctl enable kiwix depot nginx dnsmasq
sudo systemctl start kiwix depot
```

---

## Part 9 — Reboot & Test

```bash
sudo reboot
```

After reboot:
1. Connect phone/laptop to **JayCamp** WiFi
2. Open browser → `192.168.4.1` → BASE CAMP portal
3. Open browser → `192.168.4.1:81` → DEPOT file manager

---

## Maintenance

| Task | Command |
|---|---|
| Add new ZIM | `sudo ./scripts/add-zim.sh` |
| Restart Kiwix | `sudo systemctl restart kiwix` |
| Restart DEPOT | `sudo systemctl restart depot` |
| Check Kiwix logs | `journalctl -u kiwix -n 50` |
| Check DEPOT logs | `journalctl -u depot -n 50` |
| Update portal UI | `sudo ./scripts/deploy-portal.sh` |
| Check disk space | `df -h` |
| List USB drives | `lsblk` |
