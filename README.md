# 📡 JayCamp — Offline Knowledge & File Station

A self-hosted offline portal for Raspberry Pi Zero 2 W. Plug in, connect to the WiFi hotspot, and browse Wikipedia, medical guides, cooking, TED talks, repair guides and more — no internet required. Includes a file manager to upload/download files across USB drives.

**Built for campers, travellers, and anyone who wants knowledge without connectivity.**

---

## What You Get

| Tool | URL | Description |
|---|---|---|
| BASE CAMP | `192.168.4.1` | Offline knowledge portal powered by Kiwix |
| DEPOT | `192.168.4.1:81` | File manager with USB drive support |

Both run on the Pi's own WiFi hotspot — any phone or laptop just connects and opens the browser. No app, no setup on the client device.

---

## Hardware Required

- Raspberry Pi Zero 2 W (~$15)
- Micro SD card (32GB minimum, 64GB+ recommended)
- Micro USB OTG adapter (for USB drives)
- USB drive (for extra ZIM library storage)
- Power bank or 5V USB power supply

**Total cost: ~$25-40 one time. Zero ongoing costs.**

---

## Quick Start

```bash
# Clone the repo on your Pi
git clone https://github.com/YOURUSERNAME/jaycamp.git
cd jaycamp

# Run the installer
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

That's it. The installer handles everything — hotspot, Kiwix, DEPOT, nginx, auto-mount, boot services.

After install, reboot and connect to **JayCamp** WiFi.

---

## Adding Content (ZIM Files)

Download ZIM files from [library.kiwix.org](https://library.kiwix.org) on your computer, copy to a USB drive, plug into the Pi, then:

```bash
sudo ./scripts/add-zim.sh
```

This auto-detects ZIM files on your USB drive, copies them to the library, and re-indexes Kiwix.

**Recommended ZIMs to start:**

| ZIM | Size | Content |
|---|---|---|
| wikipedia_en_top_maxi | ~7GB | Top 100k Wikipedia articles |
| wikivoyage_en_all_nopic | ~230MB | Travel guides |
| medlineplus.gov_en_all | ~500MB | Medical encyclopedia |
| freecodecamp_en_all | ~8MB | Learn to code |
| foss.cooking_en_all | ~200MB | Recipes |
| ted_mul_* | ~300MB each | TED talks by category |

---

## Manual Setup

See [docs/MANUAL_SETUP.md](docs/MANUAL_SETUP.md) for a full step-by-step guide if you prefer to set things up yourself.

---

## Customising the Portal

Edit `portal/index.html` to add/remove library cards matching your ZIM files. Each card just needs the ZIM book ID in the href.

Edit `nginx/basecamp.conf` to add proxy locations for new ZIMs.

Then run:
```bash
sudo ./scripts/deploy-portal.sh
```

---

## Project Structure

```
jaycamp/
├── scripts/
│   ├── install.sh          # One-shot full installer
│   ├── add-zim.sh          # Add new ZIM files from USB
│   └── deploy-portal.sh    # Update portal UI
├── portal/
│   ├── index.html          # BASE CAMP portal UI
│   └── files.html          # DEPOT file manager UI
├── nginx/
│   └── basecamp.conf       # Nginx config template
├── systemd/
│   ├── kiwix.service       # Kiwix systemd service
│   ├── depot.service       # DEPOT systemd service
│   └── usb-mount@.service  # USB auto-mount service
├── depot_server.py         # DEPOT Flask backend
└── docs/
    └── MANUAL_SETUP.md     # Full manual setup guide
```

---

## License

MIT — free to use, modify, and share.

---

## Credits

Built with [Kiwix](https://kiwix.org), [Flask](https://flask.palletsprojects.com), and [Nginx](https://nginx.org). ZIM content from [Kiwix Library](https://library.kiwix.org).
