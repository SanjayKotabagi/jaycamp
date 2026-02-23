#!/usr/bin/env python3
"""
DEPOT — File Manager Backend
Run on Pi Zero 2 W with: python3 depot_server.py
Serves on port 5000. Requires: pip3 install flask flask-cors
"""

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from flask import Flask, request, jsonify, send_file, abort
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Allow requests from the portal UI

# ── CONFIG ─────────────────────────────────────────────────────────────────
# Mount points to scan for drives. Add/remove as needed.
MOUNT_POINTS = [
    {
        'id': 'sd',
        'name': 'SD Card',
        'path': '/home/pi/files',   # Files folder on the SD card
        'icon': '💾'
    },
    # USB drives auto-detected below from /mnt/
]

USB_BASE = '/mnt'          # Where USB drives get mounted
MAX_UPLOAD_MB = 4096       # 4 GB max per file upload
# ───────────────────────────────────────────────────────────────────────────

app.config['MAX_CONTENT_LENGTH'] = MAX_UPLOAD_MB * 1024 * 1024


def get_drive_usage(path):
    """Return (used_gb, total_gb) for a path."""
    try:
        stat = shutil.disk_usage(path)
        return round(stat.used / 1e9, 1), round(stat.total / 1e9, 1)
    except Exception:
        return 0, 0


def detect_usb_drives():
    """Detect mounted USB drives under /mnt/"""
    usb = []
    if not os.path.isdir(USB_BASE):
        return usb
    for entry in os.scandir(USB_BASE):
        if entry.is_dir():
            # Check if something is actually mounted here
            try:
                result = subprocess.run(
                    ['mountpoint', '-q', entry.path],
                    capture_output=True
                )
                online = result.returncode == 0
            except Exception:
                online = os.path.ismount(entry.path)

            usb.append({
                'id': 'usb_' + entry.name,
                'name': entry.name.replace('_', ' ').replace('-', ' ').title(),
                'path': entry.path,
                'icon': '🔌',
                'online': online
            })
    return usb


def get_all_drives():
    """Return list of all drives with usage info."""
    drives = []

    # Static drives (SD card etc.)
    for d in MOUNT_POINTS:
        path = d['path']
        os.makedirs(path, exist_ok=True)
        used, total = get_drive_usage(path)
        drives.append({
            'id': d['id'],
            'name': d['name'],
            'path': path,
            'icon': d.get('icon', '💾'),
            'online': os.path.exists(path),
            'used': used,
            'total': total
        })

    # Auto USB drives
    for d in detect_usb_drives():
        path = d['path']
        used, total = get_drive_usage(path)
        drives.append({
            'id': d['id'],
            'name': d['name'],
            'path': path,
            'icon': d['icon'],
            'online': d['online'],
            'used': used,
            'total': total
        })

    return drives


def resolve_drive_path(drive_id, rel_path='/'):
    """Resolve a drive ID + relative path to an absolute safe path."""
    drives = get_all_drives()
    drive = next((d for d in drives if d['id'] == drive_id), None)
    if not drive:
        abort(404, 'Drive not found')

    # Safety: prevent path traversal
    base = Path(drive['path']).resolve()
    target = (base / rel_path.lstrip('/')).resolve()

    if not str(target).startswith(str(base)):
        abort(403, 'Access denied')

    return base, target, drive


# ── ROUTES ─────────────────────────────────────────────────────────────────

@app.route('/drives')
def drives():
    """List all drives."""
    return jsonify(get_all_drives())


@app.route('/files')
def list_files():
    """List files in a directory."""
    drive_id = request.args.get('drive', '')
    path = request.args.get('path', '/')

    _, target, _ = resolve_drive_path(drive_id, path)

    if not target.exists():
        abort(404, 'Path not found')
    if not target.is_dir():
        abort(400, 'Not a directory')

    entries = []
    for entry in target.iterdir():
        try:
            stat = entry.stat()
            entries.append({
                'name': entry.name,
                'type': 'dir' if entry.is_dir() else 'file',
                'size': stat.st_size if entry.is_file() else 0,
                'modified': datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
        except Exception:
            pass

    entries.sort(key=lambda x: (x['type'] != 'dir', x['name'].lower()))
    return jsonify(entries)


@app.route('/upload', methods=['POST'])
def upload():
    """Upload a file to a drive/path."""
    drive_id = request.form.get('drive', '')
    path = request.form.get('path', '/')

    _, target_dir, _ = resolve_drive_path(drive_id, path)

    if not target_dir.exists():
        abort(404, 'Target path not found')

    if 'file' not in request.files:
        abort(400, 'No file provided')

    file = request.files['file']
    if not file.filename:
        abort(400, 'Empty filename')

    # Sanitise filename
    safe_name = Path(file.filename).name
    dest = target_dir / safe_name

    # Don't overwrite — add suffix if exists
    counter = 1
    stem = dest.stem
    suffix = dest.suffix
    while dest.exists():
        dest = target_dir / f"{stem}_{counter}{suffix}"
        counter += 1

    file.save(str(dest))
    return jsonify({'ok': True, 'saved': dest.name})


@app.route('/download')
def download():
    """Download a file."""
    drive_id = request.args.get('drive', '')
    path = request.args.get('path', '/')
    filename = request.args.get('file', '')

    _, target_dir, _ = resolve_drive_path(drive_id, path)
    file_path = (target_dir / filename).resolve()

    if not str(file_path).startswith(str(target_dir)):
        abort(403)

    if not file_path.exists() or not file_path.is_file():
        abort(404)

    return send_file(str(file_path), as_attachment=True)


@app.route('/delete', methods=['POST'])
def delete():
    """Delete a file or empty directory."""
    data = request.get_json()
    drive_id = data.get('drive', '')
    path = data.get('path', '/')
    name = data.get('name', '')

    _, target_dir, _ = resolve_drive_path(drive_id, path)
    target = (target_dir / name).resolve()

    if not str(target).startswith(str(target_dir)):
        abort(403)

    if not target.exists():
        abort(404)

    if target.is_dir():
        shutil.rmtree(str(target))
    else:
        target.unlink()

    return jsonify({'ok': True})


@app.route('/mkdir', methods=['POST'])
def mkdir():
    """Create a new folder."""
    data = request.get_json()
    drive_id = data.get('drive', '')
    path = data.get('path', '/')
    name = data.get('name', '')

    if not name or '/' in name or name.startswith('.'):
        abort(400, 'Invalid folder name')

    _, target_dir, _ = resolve_drive_path(drive_id, path)
    new_dir = (target_dir / name).resolve()

    if not str(new_dir).startswith(str(target_dir)):
        abort(403)

    new_dir.mkdir(parents=False, exist_ok=False)
    return jsonify({'ok': True})


# ── MAIN ───────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("""
  ╔══════════════════════════════════╗
  ║   DEPOT File Server — v1.0       ║
  ║   Running on http://0.0.0.0:5000 ║
  ╚══════════════════════════════════╝
    """)
    # Ensure SD card files folder exists
    os.makedirs('/home/pi/files', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
