---
title: Build e distribuzione
type: system
tags: [build, export]
updated: 2026-10-20
sources: [build.sh, run.sh, export_presets.cfg, tools/fetch_templates.py]
---

# Build e distribuzione

- `./run.sh` avvia il gioco dal progetto (Godot nel PATH).
- `./build.sh` esporta `build/AncientsClash.x86_64` (~89 MB, pck incorporato): un solo file da copiare sull'altro PC Linux.
- I template ufficiali (1.3 GB) non vengono scaricati per intero: `tools/fetch_templates.py` estrae solo `linux_release.x86_64` e `version.txt` con richieste HTTP Range (~28 MB compressi) in `~/.local/share/godot/export_templates/4.7.2.stable/`.
- Il preset esclude `screenshots/`, `tools/`, `wiki/`, `build/`.
- Verifica: l'eseguibile esportato supera `--autotest-training`.
