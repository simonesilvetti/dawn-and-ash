---
title: Build e distribuzione
type: system
tags: [build, export]
updated: 2026-10-22
sources: [build.sh, run.sh, export_presets.cfg, tools/fetch_templates.py, tools/make_installer.sh]
---

# Build e distribuzione

- `./run.sh` avvia il gioco dal progetto (Godot nel PATH).
- `./build.sh` esporta `build/DawnAndAsh.x86_64` (~103 MB, pck incorporato): un solo file da copiare sull'altro PC Linux.
- Poi `tools/make_installer.sh` crea `build/DawnAndAsh-<versione>-linux-x86_64.run` (~59 MB), un installer autoestraente
  (script `sh` + `tar.gz`). Non servono root né dipendenze. Installa in `~/.local/opt/dawn-and-ash`, crea il comando
  `~/.local/bin/dawn-and-ash`, la voce `.desktop` e l'icona; con `--uninstall` toglie tutto tranne le impostazioni.
- Identificativo dell'applicazione: `com.atomicgrove.dawnandash` (`Game.APP_ID`), usato per il file `.desktop` e l'icona.
  Convenzione dell'autore: tutti i suoi programmi usano `com.atomicgrove.<nome>`.
- Le impostazioni stanno in `~/.local/share/dawn-and-ash/` (`config/custom_user_dir_name` in `project.godot`).
- Perché non Flatpak o AppImage: Flatpak richiede che l'utente abbia `flatpak` e scarichi un runtime da centinaia di MB;
  AppImage su molte distribuzioni recenti richiede `libfuse2`, spesso assente. Il `.run` funziona ovunque ci siano `sh` e `tar`.
- I template ufficiali (1.3 GB) non vengono scaricati per intero: `tools/fetch_templates.py` estrae solo `linux_release.x86_64` e `version.txt` con richieste HTTP Range (~28 MB compressi) in `~/.local/share/godot/export_templates/4.7.2.stable/`.
- Il preset esclude `screenshots/`, `tools/`, `wiki/`, `build/`.
- Verifica: l'eseguibile esportato e quello installato dal `.run` superano `--autotest-training`; installazione e
  disinstallazione provate in una home finta, `.desktop` valido (`desktop-file-validate`).
