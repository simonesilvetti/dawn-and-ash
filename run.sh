#!/usr/bin/env bash
# Avvia il gioco dal progetto (serve Godot 4.7 nel PATH). Argomenti extra passati al gioco dopo "--".
cd "$(dirname "$0")"
exec "${GODOT:-godot}" --path . -- "$@"
