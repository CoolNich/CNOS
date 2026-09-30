#!/bin/bash
# Builds a bootable CNOS live ISO (Debian 12 + Openbox + Chromium kiosk).
# Run on a Debian/Ubuntu machine with internet access, with cnos.html in the same folder.
# Usage: bash build-cnos-iso.sh
set -e
[ -f cnos.html ] || { echo "Put cnos.html next to this script."; exit 1; }
SRC="$(pwd)/cnos.html"
sudo apt-get update
sudo apt-get install -y live-build debootstrap debian-archive-keyring
sudo rm -rf /var/tmp/cnos-build cnos-build

# live-build cannot work in a path containing spaces, so build in /var/tmp
OUT="$(pwd)"
BUILD=/var/tmp/cnos-build
sudo rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"

lb config \
  --distribution bookworm \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --debian-installer none \
  --iso-volume CNOS \
  --iso-application CNOS \
  --bootappend-live "boot=live components quiet splash"

# Packages: minimal X, window manager, browser, VMware guest tools
mkdir -p config/package-lists
cat > config/package-lists/cnos.list.chroot <<'EOF'
xorg
xinit
openbox
chromium
fonts-dejavu
open-vm-tools
open-vm-tools-desktop
EOF

# The CNOS app itself
mkdir -p config/includes.chroot/opt/cnos
cp "$SRC" config/includes.chroot/opt/cnos/index.html

# Auto-login on tty1
D=config/includes.chroot/etc/systemd/system/getty@tty1.service.d
mkdir -p $D
cat > $D/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin user --noclear %I $TERM
EOF

# Start X on login and launch CNOS fullscreen
S=config/includes.chroot/etc/skel
mkdir -p $S
cat > $S/.bash_profile <<'EOF'
[ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && exec startx
EOF
cat > $S/.xinitrc <<'EOF'
xset s off -dpms
openbox &
exec chromium --kiosk --no-first-run --disable-infobars \
  --user-data-dir="$HOME/.cnos" file:///opt/cnos/index.html
EOF

sudo lb build

sudo cp live-image-amd64.hybrid.iso "$OUT/CNOS-boot.iso"
sudo chown "$(id -u):$(id -g)" "$OUT/CNOS-boot.iso"
echo "Done: $OUT/CNOS-boot.iso"
