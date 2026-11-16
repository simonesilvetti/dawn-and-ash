---
title: Simulazione (server autoritativo)
type: system
tags: [sim, logica]
updated: 2026-11-16
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
- **Eroi** (dal 2026-10-22): `add_hero(peer, team, nome, eroe)`; l'id dell'eroe ("kael", "peppino", "gorm") sta in
  `HeroData.hero` e in `Unit.subtype` (arriva ai client con l'evento spawn). Abilità ed effetti vengono da
  `Game.HEROES[id]`. Stati nuovi per [[peppino]]: carica (`Unit.dash_*`, `_update_dash`, non interrompibile, stato
  CASTING) e riduzione dei danni (`shield_time/shield_pct`, applicata in `_damage`, flag `F_SHIELDED`).
  `walk_to_range` nelle abilità indica quelle che camminano fino a gittata (la Meteora).
- **Gorm** (dal 2026-11-16, vedi [[gorm]]): **muri** temporanei della Fenditura (`Sim.walls`): `_move_towards` spinge
  fuori dai muri (`MapData.push_from_wall`) e li aggira puntando all'angolo oltre l'estremità dal lato della meta
  (`MapData.wall_detour`, senza memoria); anche la separazione rispetta i muri. **Balzo** (`Unit.dash_leap`, sopra i muri),
  **attacco potenziato** (`Unit.empower_*`, flag `F_EMPOWERED`), abilità **passive** (`target: "passive"`, mai lanciabili:
  la Scossa di ritorno è chiamata da `_aftershock` dopo ogni abilità), `Sim.delayed` generalizzato con il tipo `echo`.
- Prestazioni: circa 1 ms per tick con 50–60 unità sul chip più lento provato. → [[prestazioni]]
