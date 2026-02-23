#!/bin/bash
# =============================================================================
# JayCamp — Add / Re-index ZIM Files
# Copy your ZIM files to /home/pi/library/ first, then run this script.
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

LIBRARY_DIR="/home/pi/library"

echo -e "${CYAN}[JayCamp] ZIM Indexer${NC}"
echo ""

# Count ZIM files
ZIM_COUNT=$(ls "$LIBRARY_DIR"/*.zim 2>/dev/null | wc -l)

if [ "$ZIM_COUNT" -eq 0 ]; then
  echo -e "${RED}No ZIM files found in $LIBRARY_DIR${NC}"
  echo ""
  echo "Copy your ZIM files there first:"
  echo "  scp yourfile.zim pi@basecamp.local:/home/pi/library/"
  echo ""
  echo "Download ZIM files from: https://library.kiwix.org"
  exit 1
fi

echo -e "${YELLOW}Found $ZIM_COUNT ZIM file(s) in $LIBRARY_DIR:${NC}"
for zim in "$LIBRARY_DIR"/*.zim; do
  SIZE=$(du -sh "$zim" 2>/dev/null | cut -f1)
  echo "  [$SIZE] $(basename "$zim")"
done
echo ""

# Rebuild library index from scratch
echo -e "${YELLOW}Rebuilding library index...${NC}"
echo '<?xml version="1.0" encoding="UTF-8"?><library version="1.0"></library>' > "$LIBRARY_DIR/library.xml"
chown pi:pi "$LIBRARY_DIR/library.xml"

for zim in "$LIBRARY_DIR"/*.zim; do
  echo "  Indexing: $(basename "$zim")..."
  sudo -u pi kiwix-manage "$LIBRARY_DIR/library.xml" add "$zim" 2>/dev/null || \
    echo "  Warning: could not index $(basename "$zim")"
done

echo ""
echo -e "${YELLOW}Restarting Kiwix...${NC}"
systemctl restart kiwix
sleep 2

systemctl is-active --quiet kiwix && \
  echo -e "${GREEN}Kiwix running. Visit http://192.168.4.1${NC}" || \
  echo -e "${RED}Kiwix failed — check: journalctl -u kiwix -n 20${NC}"

echo ""
echo -e "${YELLOW}Reminder: For each new ZIM, add a card in portal/index.html${NC}"
echo -e "${YELLOW}and a location block in nginx/basecamp.conf, then run:${NC}"
echo -e "${YELLOW}  sudo ./scripts/deploy-portal.sh && sudo systemctl reload nginx${NC}"
