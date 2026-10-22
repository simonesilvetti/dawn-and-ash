---
title: Controlli
type: concept
tags: [input]
updated: 2026-10-20
sources: [scripts/world/World.gd, scripts/autoload/Game.gd]
---

# Controlli

| Input | Azione |
|---|---|
| Click destro | muovi / attacca il nemico sotto il cursore (tenuto premuto: ordini continui) |
| A + click sinistro | attacco-movimento; su un proprio creep sotto il 50%: deny |
| S | fermati |
| Q W E R | abilità (mira + click sinistro; click destro/Esc annulla) |
| Ctrl + Q/W/E/R | impara/potenzia abilità |
| 1–6 | usa oggetto |
| B | negozio (anche pulsante "Negozio (B)" nell'HUD o click sinistro sulla propria fontana) |
| Frecce / bordi dello schermo | scorri la telecamera; rotella = zoom |
| Spazio (tenuto) | centra sull'eroe; Y = blocca la telecamera |
| Minimappa | click sinistro sposta la visuale, click destro muove l'eroe |
| Tab | tabella punteggio |
| Esc / F10 | menu di pausa (in allenamento ferma il gioco) |
| F12 | screenshot in `screenshots/` |
| M | musica sì/no |

Azioni definite in `Game._setup_input` (tasti fisici). Il cursore diventa un mirino sui nemici e durante la mira.
