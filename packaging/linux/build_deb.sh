#!/usr/bin/env bash
# Build a .deb installer package for Founders: Barter & Block.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXECUTABLE="${1:-$REPO_ROOT/builds/founders-barter-and-block.x86_64}"
OUTPUT_DIR="${2:-$REPO_ROOT/builds}"

if [ ! -f "$EXECUTABLE" ]; then
    echo "error: executable not found: $EXECUTABLE" >&2
    echo "       export the Linux build first (see export_presets.cfg)" >&2
    exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "error: dpkg-deb is not installed (needed to build the .deb)" >&2
    exit 1
fi

VERSION="$(sed -n 's/^config\/version="\([^"]*\)"$/\1/p' "$REPO_ROOT/project.godot" | head -n 1)"
if [ -z "$VERSION" ]; then
    echo "error: could not read config/version from $REPO_ROOT/project.godot" >&2
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p \
    "$STAGE/opt/founders-barter-and-block" \
    "$STAGE/usr/bin" \
    "$STAGE/usr/share/applications" \
    "$STAGE/usr/share/icons/hicolor/scalable/apps" \
    "$STAGE/usr/share/doc/founders-barter-and-block" \
    "$STAGE/DEBIAN"

find "$STAGE" -type d -exec chmod 0755 {} +

install -m 0755 "$EXECUTABLE" "$STAGE/opt/founders-barter-and-block/founders-barter-and-block.x86_64"
ln -s /opt/founders-barter-and-block/founders-barter-and-block.x86_64 "$STAGE/usr/bin/founders-barter-and-block"
install -m 0644 "$SCRIPT_DIR/founders-barter-and-block.desktop" "$STAGE/usr/share/applications/founders-barter-and-block.desktop"
install -m 0644 "$REPO_ROOT/icon.svg" "$STAGE/usr/share/icons/hicolor/scalable/apps/founders-barter-and-block.svg"
install -m 0644 "$REPO_ROOT/LICENSE" "$STAGE/usr/share/doc/founders-barter-and-block/copyright"

INSTALLED_SIZE="$(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: founders-barter-and-block
Version: $VERSION
Section: games
Priority: optional
Architecture: amd64
Maintainer: sramteare <sramteare@users.noreply.github.com>
Installed-Size: $INSTALLED_SIZE
Depends: libc6, libgl1, libx11-6, libxcursor1, libxinerama1, libxrandr2, libxi6
Homepage: https://github.com/sramteare/founders-barter-and-block
Description: Founders: Barter & Block
 Hex-board resource trading and strategy game against AI players or hot-seat.
EOF
chmod 0644 "$STAGE/DEBIAN/control"

MAINTAINER_SCRIPT_HEADER='#!/bin/sh
set -e'

for script in postinst postrm; do
    {
        printf '%s\n' "$MAINTAINER_SCRIPT_HEADER"
        cat <<'EOF'
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF
    } > "$STAGE/DEBIAN/$script"
    chmod 0755 "$STAGE/DEBIAN/$script"
done

mkdir -p "$OUTPUT_DIR"
DEB_PATH="$(cd "$OUTPUT_DIR" && pwd)/founders-barter-and-block_${VERSION}_amd64.deb"

dpkg-deb --build --root-owner-group "$STAGE" "$DEB_PATH"

echo "$DEB_PATH"
