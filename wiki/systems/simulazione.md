---
title: Simulazione (server autoritativo)
type: system
tags: [sim, logica]
updated: 2026-10-22
sources: [scripts/sim/Sim.gd, scripts/sim/Unit.gd]
---

# Simulazione (server autoritativo)

`Sim` è un `RefCounted` con tick fisso (`Game.TICK_RATE` = 30 Hz). Ordine di un tick:
comandi → ondate → `prev_pos` → griglia spaziale → aggiornamento unità (stati alterati, cast, windup, IA, movimento, attacco) → proiettili → effetti ritardati → separazione → rigenerazione/fontane → eroi (oro, ricariche, pozioni, rinascita) → pulizia.

## Dettagli
- **Unità** (`Unit`): dati puri; stati IDLE/MOVING/ATTACKING/CASTING/DEAD; flag compatti per la rete.
- **Attacco**: "windup" fino al punto d'impatto (`attack_point`), poi danno (corpo a corpo) o proiettile a ricerca. Un nuovo ordine annulla il windup (come in Dota).
- **Griglia spaziale** a celle di 8 m, ricostruita a ogni tick riusando gli array; `_query()` per i vicini.
- **Separazione** tra unità: coppie confrontate solo tra celle adiacenti (metà vicinato), nessuna allocazione; gli eroi vengono spinti meno.
- **Eventi** (array compatti): spawn, despawn, death, respawn, attack, cast, proj, proj_end, dmg, gold, fx, notify, wave, game_over.
- **Comandi** convalidati: move, amove, attack, stop, cast, learn, buy, sell, use, cheat (solo allenamento).
- **Eroi** (dal 2026-10-22): `add_hero(peer, team, nome, eroe)`; l'id dell'eroe ("kael", "peppino") sta in
  `HeroData.hero` e in `Unit.subtype` (arriva ai client con l'evento spawn). Abilità ed effetti vengono da
  `Game.HEROES[id]`. Stati nuovi per [[peppino]]: carica (`Unit.dash_*`, `_update_dash`, non interrompibile, stato
  CASTING) e riduzione dei danni (`shield_time/shield_pct`, applicata in `_damage`, flag `F_SHIELDED`).
  `walk_to_range` nelle abilità indica quelle che camminano fino a gittata (la Meteora).
- Prestazioni: circa 1 ms per tick con 50–60 unità sul chip più lento provato. → [[prestazioni]]
