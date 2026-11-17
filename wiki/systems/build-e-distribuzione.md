---
title: Build e distribuzione
type: system
tags: [build, export]
updated: 2026-11-17
sources: [build.sh, run.sh, export_presets.cfg, icon.ico, tools/fetch_templates.py, tools/make_installer.sh, tools/make_windows_zip.sh, tools/windows_tests.sh]
---

# Build e distribuzione

- `./run.sh` avvia il gioco dal progetto (Godot nel PATH).
- `./build.sh` costruisce Linux e Windows; `./build.sh linux` o `./build.sh windows` una sola piattaforma.
- Linux: esporta `build/DawnAndAsh.x86_64` (~103 MB, pck incorporato): un solo file da copiare sull'altro PC Linux.
- Poi `tools/make_installer.sh` crea `build/DawnAndAsh-<versione>-linux-x86_64.run` (~59 MB), un installer autoestraente
  (script `sh` + `tar.gz`). Non servono root né dipendenze. Installa in `~/.local/opt/dawn-and-ash`, crea il comando
  `~/.local/bin/dawn-and-ash`, la voce `.desktop` e l'icona; con `--uninstall` toglie tutto tranne le impostazioni.
- Windows (preset "Windows Desktop", esportato da Linux senza Wine): `build/DawnAndAsh.exe` (~138 MB, pck incorporato).
  Poi `tools/make_windows_zip.sh` crea `build/DawnAndAsh-<versione>-windows-x86_64.zip` (~68 MB) con l'exe, `LICENSE.txt`
  e `LEGGIMI.txt` (avvio, avviso SmartScreen, firewall). Niente installer: si estrae e si avvia, come molti giochi indie.
- Icona e metadati dell'exe (`application/modify_resources`): Godot 4.7 li scrive da solo, senza `rcedit`. L'icona è
  `icon.ico` (16–256 px, generata da `icon.svg` con `rsvg-convert` + `magick`); azienda Atomic Grove, versione da `project.godot`.
- L'exe non è firmato (`codesign/enable=false`): SmartScreen avvisa al primo avvio. Per toglierlo serve un certificato
  di firma del codice a pagamento.
- Su Windows le impostazioni stanno in `%APPDATA%\dawn-and-ash\`.
- Identificativo dell'applicazione: `com.atomicgrove.dawnandash` (`Game.APP_ID`), usato per il file `.desktop` e l'icona.
  Convenzione dell'autore: tutti i suoi programmi usano `com.atomicgrove.<nome>`.
- Le impostazioni stanno in `~/.local/share/dawn-and-ash/` (`config/custom_user_dir_name` in `project.godot`).
- Pubblicazione: repository GitHub pubblico `simonesilvetti/dawn-and-ash`; il `.run` e lo zip Windows vanno allegati a ogni Release (dalla v0.2.0).
- Perché non Flatpak o AppImage: Flatpak richiede che l'utente abbia `flatpak` e scarichi un runtime da centinaia di MB;
  AppImage su molte distribuzioni recenti richiede `libfuse2`, spesso assente. Il `.run` funziona ovunque ci siano `sh` e `tar`.
- I template ufficiali (1.3 GB) non vengono scaricati per intero: `tools/fetch_templates.py <versione> [linux] [windows]` estrae solo `linux_release.x86_64` / `windows_release_x86_64.exe` e `version.txt` con richieste HTTP Range (~28 MB e ~38 MB compressi) in `~/.local/share/godot/export_templates/4.7.2.stable/`.
- I preset escludono `screenshots/`, `tools/`, `wiki/`, `build/`.
- Verifica: l'eseguibile esportato e quello installato dal `.run` superano `--autotest-training`; installazione e
  disinstallazione provate in una home finta, `.desktop` valido (`desktop-file-validate`).

## Prova della build Windows
Senza un PC Windows, `tools/windows_tests.sh` prova l'exe con **Wine** (`sudo pacman -S wine`, ~78 MB da scaricare),
in un prefisso temporaneo che cancella alla fine. Esito del 2026-10-26 (Wine 11.17, v0.2.0):
- autotest allenamento sull'exe: `AUTOTEST OK` (tutti i controlli, audio compreso);
- grafica: Vulkan Forward+ sulla Intel Iris Xe, 24 screenshot identici a quelli Linux (menu, HUD, negozio, VFX, vittoria);
- rete Linux↔Windows in tutte e due le direzioni, anche a 150 ms con jitter e perdite: numeri come tra due Linux
  (vedi [[test-di-rete]]).

Release **v0.3.0** (2026-11-17, con [[gorm]]): stesse prove sulle build esportate. Eseguibile Linux `AUTOTEST OK`;
exe sotto Wine `AUTOTEST OK`; rete Linux↔Windows 0.159 / 0.161 m (max 1.23), a 150 ms + jitter + 3% 0.202 m (2.12).
Allegati: `.run` 58 MB, zip Windows 67 MB, eseguibile Linux singolo 103 MB.

> [!warning]
> Wine non è Windows: avviso SmartScreen, firewall, driver video Windows (e l'eventuale D3D12) restano da provare su
> un PC Windows vero.
