#!/usr/bin/env bash
# Crea build/DawnAndAsh-<versione>-linux-x86_64.run: un installer autoestraente (script sh + archivio tar.gz).
# L'utente lo scarica, lo rende eseguibile e lo avvia: niente root, niente dipendenze oltre a sh e tar.
# Installa in ~/.local/opt/dawn-and-ash, aggiunge il comando dawn-and-ash, la voce nel menu delle applicazioni
# e l'icona (identificativo com.atomicgrove.dawnandash); "--uninstall" rimuove tutto (le impostazioni in ~/.local/share/dawn-and-ash restano).
set -euo pipefail
cd "$(dirname "$0")/.."
BIN=build/DawnAndAsh.x86_64
[[ -x "$BIN" ]] || { echo "Manca $BIN: esegui prima ./build.sh"; exit 1; }
VER="$(grep -oP '^config/version="\K[^"]+' project.godot)"
OUT="build/DawnAndAsh-${VER}-linux-x86_64.run"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$BIN" "$STAGE/DawnAndAsh.x86_64"
cp icon.svg "$STAGE/com.atomicgrove.dawnandash.svg"

cat > "$OUT" <<'HEADER'
#!/bin/sh
# Dawn & Ash — installer per Linux (x86_64). Uso: sh DawnAndAsh-*.run [--uninstall]
set -e
APP=dawn-and-ash
APP_ID=com.atomicgrove.dawnandash
DEST="$HOME/.local/opt/$APP"
BINDIR="$HOME/.local/bin"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP="$DATA/applications/$APP_ID.desktop"
ICON="$DATA/icons/hicolor/scalable/apps/$APP_ID.svg"

refresh_menu() {
	command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
	command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true
}

if [ "$1" = "--uninstall" ]; then
	rm -rf "$DEST"
	rm -f "$BINDIR/$APP" "$DESKTOP" "$ICON"
	refresh_menu
	echo "Dawn & Ash disinstallato (le impostazioni restano in $DATA/$APP)."
	exit 0
fi

if [ "$(uname -m)" != "x86_64" ]; then
	echo "Errore: serve Linux a 64 bit (x86_64), questo sistema è $(uname -m)."
	exit 1
fi

echo "Installo Dawn & Ash in $DEST ..."
LINE=$(awk '/^__PAYLOAD__$/ { print NR + 1; exit }' "$0")
rm -rf "$DEST"
mkdir -p "$DEST" "$BINDIR" "$DATA/applications" "$(dirname "$ICON")"
tail -n +"$LINE" "$0" | tar -xzf - -C "$DEST"
chmod +x "$DEST/DawnAndAsh.x86_64"
cp "$DEST/$APP_ID.svg" "$ICON"
cp "$0" "$DEST/uninstall.run" 2>/dev/null || true

cat > "$BINDIR/$APP" <<EOF
#!/bin/sh
exec "$DEST/DawnAndAsh.x86_64" "\$@"
EOF
chmod +x "$BINDIR/$APP"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Dawn & Ash
GenericName=MOBA
Comment=MOBA minimale in stile Dota 2 - Le Terre di Aethra (di Simone Silvetti, simonesilvetti.com)
Exec="$DEST/DawnAndAsh.x86_64"
Path=$DEST
Icon=$APP_ID
Terminal=false
Categories=Game;StrategyGame;
StartupWMClass=Dawn & Ash
EOF
refresh_menu

echo "Fatto! Avvia Dawn & Ash dal menu delle applicazioni oppure con il comando: $APP"
echo "Per disinstallare: sh \"$DEST/uninstall.run\" --uninstall"
if [ -t 0 ] && [ -t 1 ]; then
	printf "Avviare il gioco ora? [S/n] "
	read -r ans || ans=n
	case "$ans" in n*|N*) ;; *) nohup "$DEST/DawnAndAsh.x86_64" >/dev/null 2>&1 & ;; esac
fi
exit 0
__PAYLOAD__
HEADER

tar -czf - -C "$STAGE" . >> "$OUT"
chmod +x "$OUT"
ls -lh "$OUT"
