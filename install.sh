#!/usr/bin/env bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/shyamshankar/clession/main/bin/clession"
INSTALL_DIR="${INSTALL_DIR:-$HOME/bin}"

echo "Installing clession to $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"
curl -fsSL "$REPO" -o "$INSTALL_DIR/clession"
chmod +x "$INSTALL_DIR/clession"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo ""
    echo "NOTE: $INSTALL_DIR is not in your PATH."
    echo "Add this to your shell profile:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "Done! Run 'clession doctor' to verify your setup."
