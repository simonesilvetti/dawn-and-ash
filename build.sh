#!/usr/bin/env bash
# Esporta gli eseguibili autonomi (pck incorporato) e i pacchetti da distribuire:
#   Linux:   build/DawnAndAsh.x86_64 + installer build/DawnAndAsh-<versione>-linux-x86_64.run (tools/make_installer.sh)
#   Windows: build/DawnAndAsh.exe    + zip       build/DawnAndAsh-<versione>-windows-x86_64.zip (tools/make_windows_zip.sh)
# Uso: ./build.sh [linux] [windows]   (senza argomenti: entrambe le piattaforme)
# Al primo uso scarica i soli template necessari (~70 MB per piattaforma) con tools/fetch_templates.py.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
PLATFORMS=("$@")
[[ ${#PLATFORMS[@]} -gt 0 ]] || PLATFORMS=(linux windows)
VER="$("$GODOT" --version | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?')"
TPL_DIR="$HOME/.local/share/godot/export_templates/${VER}.stable"
declare -A TEMPLATE=([linux]=linux_release.x86_64 [windows]=windows_release_x86_64.exe)
missing=()
for p in "${PLATFORMS[@]}"; do
	[[ -n "${TEMPLATE[$p]:-}" ]] || { echo "Piattaforma sconosciuta: $p (usa linux o windows)"; exit 1; }
	[[ -f "$TPL_DIR/${TEMPLATE[$p]}" ]] || missing+=("$p")
done
if [[ ${#missing[@]} -gt 0 ]]; then
	echo "Template di esportazione mancanti per Godot $VER (${missing[*]}): li scarico..."
	python3 tools/fetch_templates.py "$VER" "${missing[@]}"
fi
[[ -d assets/models ]] || ./tools/fetch_assets.sh
mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for p in "${PLATFORMS[@]}"; do
	case "$p" in
	linux)
		"$GODOT" --headless --path . --export-release "Linux" build/DawnAndAsh.x86_64
		chmod +x build/DawnAndAsh.x86_64
		ls -lh build/DawnAndAsh.x86_64
		./tools/make_installer.sh
		;;
	windows)
		"$GODOT" --headless --path . --export-release "Windows Desktop" build/DawnAndAsh.exe
		ls -lh build/DawnAndAsh.exe
		./tools/make_windows_zip.sh
		;;
	esac
done
echo "Fatto: distribuisci build/DawnAndAsh-*.run (Linux) e build/DawnAndAsh-*-windows-x86_64.zip (Windows)."
