#!/bin/bash
# =============================================================================
# JayCamp — Deploy Portal
# Updates the portal UI files on the Pi
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORTAL_DIR="/home/pi/portal"

echo "[JayCamp] Deploying portal files..."

cp "$REPO_DIR/portal/index.html" "$PORTAL_DIR/index.html"
cp "$REPO_DIR/portal/files.html" "$PORTAL_DIR/files.html"
chmod 644 "$PORTAL_DIR"/*
chmod 755 "$PORTAL_DIR"

echo "Done. Reload your browser to see changes."
