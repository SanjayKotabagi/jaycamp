#!/bin/bash
# =============================================================================
# JayCamp — Add ZIM Files
# Detects ZIM files on USB drive and adds them to the library
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

LIBRARY_DIR="/home/pi/library"

echo -e "${CYAN}[JayCamp] ZIM File Importer${NC}"
echo ""

# Find mounted USB drives
USB_MOUNTS=$(lsblk -o MOUNTPOINT -nr | grep "^/mnt/" | head -5)

if [ -z "$USB_MOUNTS" ]; then
  echo -e "${RED}No USB drives found. Plug in your USB drive and try again.${NC}"
  echo "If just plugged in, wait 5 seconds and retry."
  exit 1
fi

echo "Found drives:"
echo "$USB_MOUNTS"
echo ""

# Find all ZIM files on all USB mounts
ZIM_FILES=()
while IFS= read -r mount; do
  while IFS= read -r -d '' zim; do
    ZIM_FILES+=("$zim")
  done < <(find "$mount" -maxdepth 3 -name "*.zim" -print0 2>/dev/null)
done <<< "$USB_MOUNTS"

if [ ${#ZIM_FILES[@]} -eq 0 ]; then
  echo -e "${RED}No ZIM files found on USB drives.${NC}"
  echo "Download ZIM files from https://library.kiwix.org and copy to your USB drive."
  exit 1
fi

echo -e "${YELLOW}Found ${#ZIM_FILES[@]} ZIM file(s):${NC}"
for zim in "${ZIM_FILES[@]}"; do
  SIZE=$(du -sh "$zim" 2>/dev/null | cut -f1)
  echo "  [$SIZE] $(basename "$zim")"
done
echo ""

read -p "Copy all to library and index? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo -e "${YELLOW}Copying ZIM files...${NC}"
for zim in "${ZIM_FILES[@]}"; do
  DEST="$LIBRARY_DIR/$(basename "$zim")"
  if [ -f "$DEST" ]; then
    echo "  Skipping (already exists): $(basename "$zim")"
  else
    echo "  Copying: $(basename "$zim")..."
    cp "$zim" "$DEST"
    chown pi:pi "$DEST"
    echo -e "  ${GREEN}Done.${NC}"
  fi
done

echo ""
echo -e "${YELLOW}Indexing library...${NC}"
# Re-build library.xml from scratch
echo '<?xml version="1.0" encoding="UTF-8"?><library version="1.0"></library>' > "$LIBRARY_DIR/library.xml"
for zim in "$LIBRARY_DIR"/*.zim; do
  [ -f "$zim" ] || continue
  echo "  Indexing: $(basename "$zim")..."
  sudo -u pi kiwix-manage "$LIBRARY_DIR/library.xml" add "$zim" 2>/dev/null || echo "  Warning: could not index $zim"
done

echo ""
echo -e "${YELLOW}Restarting Kiwix...${NC}"
systemctl restart kiwix
sleep 2
systemctl is-active --quiet kiwix && echo -e "${GREEN}Kiwix running.${NC}" || echo -e "${RED}Kiwix failed to start — check: journalctl -u kiwix -n 20${NC}"

echo ""
echo -e "${GREEN}Done! Your new content is available at http://192.168.4.1${NC}"
echo ""
echo -e "${YELLOW}Don't forget to update portal/index.html to add cards for new ZIMs,${NC}"
echo -e "${YELLOW}then run: sudo ./scripts/deploy-portal.sh${NC}"
