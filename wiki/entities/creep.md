---
title: Creep
type: entity
tags: [unità, ia]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd]
---

# Creep

Ondata ogni **30 s** (la prima a 5 s): 3 corpo a corpo + 1 a distanza per squadra; dalla 5ª ondata, ogni 5, anche un **creep d'assedio** (Fase 2).
Ogni 5 minuti +10% vita e danno (Fase 2). Tetto di sicurezza: `Game.MAX_UNITS` = 90 unità vive.

| Tipo | Vita | Danno | Intervallo | Gittata | Velocità | Armatura |
|---|---|---|---|---|---|---|
| Corpo a corpo | 550 | 20 | 1.0 s | 1.4 | 5 | 2 |
| A distanza | 300 | 24 | 1.0 s | 5 | 5 | 0 |
| Assedio | 900 | 40 (×2.5 sugli edifici) | 2.5 s | 7 | 3.5 | 0 |

Fonte: `Game.CREEPS`. Last hit: 35–45 oro (+30 per l'assedio), 40 XP divisi tra gli eroi nemici entro 12 m.

## IA (`Sim._creep_ai`)
Aggiornata ogni 0.2 s, sfasata tra le unità. Seguono la corsia con un offset laterale; bersagli entro 8 m con priorità:
1. eroe nemico che ha appena attaccato un nostro eroe; 2. creep più vicino; 3. edificio; 4. eroe.
Abbandonano l'inseguimento oltre 12 m dal punto in cui hanno lasciato la corsia. La ricerca usa la griglia spaziale. → [[simulazione]]

## Deny (Fase 2)
L'eroe può attaccare un proprio creep sotto il 50% (A + click): niente oro al nemico, che riceve solo metà esperienza.
