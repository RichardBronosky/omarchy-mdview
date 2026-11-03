#!/usr/bin/env bash
# Adds the `mdview` command and a "Markdown Viewer" Open With entry.
#   ./install.sh            install, keep the current default .md app
#   ./install.sh --default  install and make mdview the default for .md
#   ./install.sh --remove   undo everything this script did
set -euo pipefail

plugin_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
bin="$HOME/.local/bin/mdview"
apps="$HOME/.local/share/applications"
desktop="$apps/mdview.desktop"
mimes=(text/markdown text/x-markdown)

if [[ ${1:-} == --remove ]]; then
  rm -f "$bin" "$desktop"
  update-desktop-database "$apps" 2>/dev/null || true
  echo "Removed $bin and $desktop"
  exit 0
fi

# Adding a .desktop file can silently change the default .md app when no
# default was set explicitly, so remember it and pin it back afterwards.
previous=$(xdg-mime query default text/markdown 2>/dev/null || true)

mkdir -p "$(dirname "$bin")" "$apps"
ln -sf "$plugin_dir/bin/mdview" "$bin"
cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Markdown Viewer
Comment=Quick-look Markdown viewer (Omarchy plugin bronosky.mdview)
Exec=$bin %F
Icon=text-markdown
Terminal=false
MimeType=text/markdown;text/x-markdown;
Categories=Utility;Viewer;
EOF
update-desktop-database "$apps" 2>/dev/null || true

if [[ ${1:-} == --default ]]; then
  for m in "${mimes[@]}"; do xdg-mime default mdview.desktop "$m"; done
  echo "mdview is now the default for Markdown files."
elif [[ -n $previous && $previous != mdview.desktop ]]; then
  for m in "${mimes[@]}"; do xdg-mime default "$previous" "$m"; done
  echo "Kept $previous as the default. Run ./install.sh --default to switch."
fi

echo "Installed: mdview FILE.md, plus 'Markdown Viewer' in Open With."
