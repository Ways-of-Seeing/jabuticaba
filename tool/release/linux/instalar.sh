#!/bin/sh
# Instala o jabuticaba só para o seu usuário (sem sudo):
# app em ~/.local/share/jabuticaba, comando em ~/.local/bin e atalho no menu.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/jabuticaba"
mkdir -p "$DEST" "$HOME/.local/bin" "$HOME/.local/share/applications"
cp -r "$DIR"/. "$DEST"/
ln -sf "$DEST/jabuticaba" "$HOME/.local/bin/jabuticaba"
sed -e "s|^Exec=.*|Exec=$DEST/jabuticaba|" -e "s|^Icon=.*|Icon=$DEST/jabuticaba.png|" "$DIR/jabuticaba.desktop" > "$HOME/.local/share/applications/jabuticaba.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
echo "jabuticaba instalado. Procure por \"jabuticaba\" no menu de aplicativos."
