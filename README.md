# 📡 JayCamp — Offline Knowledge & File Station

Turn a Raspberry Pi Zero 2 W into a portable offline WiFi hotspot serving Wikipedia, medical guides, cooking recipes, TED talks, repair manuals and more — straight to any phone or laptop browser. No internet required. No apps. No subscriptions.

Built for campers, travellers, and anyone who wants knowledge without connectivity.

---

## What You Get

| Tool | URL | Description |
|---|---|---|
| BASE CAMP | `192.168.4.1` | Offline knowledge portal powered by Kiwix |
| DEPOT | `192.168.4.1:81` | File manager with USB drive support |

Connect any phone or laptop to the **JayCamp** WiFi hotspot, open a browser, and everything works. No setup needed on the client device.

---

## Hardware Required

- Raspberry Pi Zero 2 W (~$15)
- 64GB micro SD card (recommended — ~15GB for a solid ZIM library, rest for files)
- Micro USB OTG adapter (for USB drives with DEPOT)
- Power bank or 5V USB power supply

**Total cost: ~$25 one time. Zero ongoing costs.**

---

## Default Library

These are the ZIM content packs included in the default portal UI. Download from [library.kiwix.org](https://library.kiwix.org):

| Content | Size | Category |
|---|---|---|
| Wikipedia Top (100k articles) | ~7GB | Encyclopedia |
| MedlinePlus | ~500MB | Health & Medicine |
| Military Field Medicine | ~200MB | Survival & First Aid |
| FOSS Cooking | ~200MB | Recipes |
| Anonymous Planet | ~100MB | Privacy & Security |
| Restarters Wiki | ~300MB | Repair Guides |
| FreeCodeCamp | ~8MB | Coding |
| WikiVoyage (no pics) | ~230MB | Travel Guides |
| TED Talks (7 categories) | ~300MB each | Ideas |

All stored directly on the SD card. A 64GB card comfortably holds all of the above with plenty of room to spare.

---

## Quick Start

**Requirements:** Raspberry Pi Zero 2 W with Raspberry Pi OS Lite 32-bit (Bookworm) installed.

```bash
# SSH into your Pi, then clone the repo
git clone https://github.com/SanjayKotabagi/jaycamp.git
cd jaycamp

# Run the one-command installer
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

The installer will:
- Install all dependencies (nginx, kiwix, flask, dnsmasq)
- Set up the WiFi hotspot with a password you choose
- Deploy the BASE CAMP portal and DEPOT file manager
- Configure all services to auto-start on boot
- Set up USB drive auto-mounting

After install, copy your ZIM files to `/home/pi/library/`, run `sudo ./scripts/add-zim.sh` to index them, then reboot.

---

## Adding ZIM Files

Download ZIM files on your computer from [library.kiwix.org](https://library.kiwix.org), copy to the Pi via SCP:

```bash
# From your computer:
scp yourfile.zim pi@basecamp.local:/home/pi/library/

# Then on the Pi — index and restart:
sudo ./scripts/add-zim.sh
```

After adding new ZIMs, add a card in `portal/index.html` and a location block in `nginx/basecamp.conf`, then:

```bash
sudo ./scripts/deploy-portal.sh
sudo systemctl reload nginx
```

---

## OS Compatibility

**Tested on:** Raspberry Pi OS Lite 32-bit (Bookworm) on Pi Zero 2 W.

> ⚠️ Bookworm uses NetworkManager instead of dhcpcd. The installer handles this correctly. Do not follow older tutorials that use hostapd or dhcpcd — they will not work on Bookworm.

---

## Project Structure

```
jaycamp/
├── README.md
├── depot_server.py         ← DEPOT Flask backend
├── portal/
│   ├── index.html          ← BASE CAMP portal UI
│   └── files.html          ← DEPOT file manager UI
├── nginx/
│   └── basecamp.conf       ← Nginx config (add ZIM locations here)
├── systemd/
│   ├── kiwix.service
│   ├── depot.service
│   └── usb-mount@.service
├── scripts/
│   ├── install.sh          ← Full one-command installer
│   ├── add-zim.sh          ← Index ZIM files after copying them
│   └── deploy-portal.sh    ← Push portal UI updates
└── docs/
    └── MANUAL_SETUP.md     ← Step-by-step manual setup guide
```

---

## Customising the Portal

Edit `portal/index.html` to add or remove library cards matching your ZIM files. Each card just needs the ZIM book ID (filename without `.zim`) in the href pointing to `http://192.168.4.1:8080/YOUR_ZIM_ID`.

Add a matching location block in `nginx/basecamp.conf`:
```nginx
location /your_zim_id_here {
    proxy_pass http://127.0.0.1:8080;
}
```

Then deploy:
```bash
sudo ./scripts/deploy-portal.sh
sudo systemctl reload nginx
```

---

## Maintenance Cheat Sheet

| Task | Command |
|---|---|
| Add new ZIM files | Copy to `/home/pi/library/` then `sudo ./scripts/add-zim.sh` |
| Update portal UI | `sudo ./scripts/deploy-portal.sh` |
| Restart Kiwix | `sudo systemctl restart kiwix` |
| Restart DEPOT | `sudo systemctl restart depot` |
| Check Kiwix logs | `journalctl -u kiwix -n 50` |
| Check disk space | `df -h` |
| List drives | `lsblk` |

---

## Manual Setup

Prefer doing it step by step? See [docs/MANUAL_SETUP.md](docs/MANUAL_SETUP.md) for the full detailed guide.

---

## License

MIT — free to use, modify, and share.

---

## Built With

[Kiwix](https://kiwix.org) · [Flask](https://flask.palletsprojects.com) · [Nginx](https://nginx.org) · [NetworkManager](https://networkmanager.dev)

ZIM content from [Kiwix Library](https://library.kiwix.org)
