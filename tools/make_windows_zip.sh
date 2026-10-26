#!/usr/bin/env bash
# Crea build/DawnAndAsh-<versione>-windows-x86_64.zip: l'eseguibile Windows autonomo (pck incorporato)
# più un LEGGIMI.txt. L'utente estrae lo zip e avvia DawnAndAsh.exe: niente installazione, niente dipendenze.
set -euo pipefail
cd "$(dirname "$0")/.."
EXE=build/DawnAndAsh.exe
[[ -f "$EXE" ]] || { echo "Manca $EXE: esegui prima ./build.sh"; exit 1; }
VER="$(grep -oP '^config/version="\K[^"]+' project.godot)"
OUT="build/DawnAndAsh-${VER}-windows-x86_64.zip"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
DIR="$STAGE/DawnAndAsh-${VER}"
mkdir -p "$DIR"
cp "$EXE" "$DIR/DawnAndAsh.exe"
cp LICENSE "$DIR/LICENSE.txt"
sed 's/$/\r/' > "$DIR/LEGGIMI.txt" <<TXT
Dawn & Ash ${VER} - MOBA minimale in stile Dota 2 (Windows 10/11, 64 bit)
di Simone Silvetti - https://simonesilvetti.com - licenza GPL-3.0-or-later

AVVIO
  Estrai questa cartella dove vuoi e fai doppio click su DawnAndAsh.exe.
  Non serve installare nulla. Per disinstallare basta cancellare la cartella
  (le impostazioni restano in %APPDATA%\\dawn-and-ash).

"WINDOWS HA PROTETTO IL PC"
  L'eseguibile non e' firmato digitalmente, quindi al primo avvio SmartScreen
  mostra un avviso. Clicca "Ulteriori informazioni" e poi "Esegui comunque".

MULTIPLAYER IN RETE
  Al primo avvio di una partita in rete il firewall di Windows chiede il permesso:
  consenti l'accesso (almeno alle reti private) per ospitare o unirti a una partita.

REQUISITI
  Scheda video con driver aggiornati (Vulkan; in mancanza si usa OpenGL).
TXT
rm -f "$OUT"
(cd "$STAGE" && zip -qr -9 "$OLDPWD/$OUT" "DawnAndAsh-${VER}")
ls -lh "$OUT"
