#!/usr/bin/env bash
# Esporta l'eseguibile Linux autonomo (pck incorporato) in build/AncientsClash.x86_64.
# Al primo uso scarica i soli template Linux necessari (~70 MB) con tools/fetch_templates.py.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
VER="$("$GODOT" --version | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?')"
TPL="$HOME/.local/share/godot/export_templates/${VER}.stable/linux_release.x86_64"
if [[ ! -x "$TPL" ]]; then
	echo "Template di esportazione mancanti per Godot $VER: li scarico..."
	python3 tools/fetch_templates.py "$VER"
fi
[[ -d assets/models ]] || ./tools/fetch_assets.sh
mkdir -p build
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Linux" build/AncientsClash.x86_64
chmod +x build/AncientsClash.x86_64
ls -lh build/AncientsClash.x86_64
echo "Fatto: copia build/AncientsClash.x86_64 sull'altro PC e avvialo (./AncientsClash.x86_64)."
