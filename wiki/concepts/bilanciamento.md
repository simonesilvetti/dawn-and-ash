---
title: Bilanciamento
type: concept
tags: [numeri, gameplay]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd]
---

# Bilanciamento

**Tutti i numeri stanno in `scripts/autoload/Game.gd`**: è la fonte di verità. Le tabelle sono in [[kael]], [[abilita]], [[creep]], [[edifici]], [[oggetti]].

## Formule
- Armatura (stile Dota): `moltiplicatore = 1 − 0.06·A / (1 + 0.06·|A|)` → `Game.armor_multiplier`.
- Danno magico: `× (1 − resistenza)`; gli eroi hanno il 25%.
- XP per livello: `100 × livello`. Raggio XP 12 m; creep 40, torre 150, eroe 200 + 20 × livello (divisi tra gli eroi vicini).
- Rinascita: `4 + 2 × livello` secondi.
- Oro: iniziale 600, +1/s, last hit 35–45, torre 200 a squadra, uccisione eroe 250.

## Interruttori di fase
`ENABLE_SIEGE`, `ENABLE_ULTIMATE`, `ENABLE_DENY`, `ENABLE_CREEP_SCALING`, `ENABLE_PHASE2_ITEMS`, `ENABLE_MUSIC_CROSSFADE` (tutti attivi). → [[fasi-di-sviluppo]]
