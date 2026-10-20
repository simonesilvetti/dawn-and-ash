---
title: Prestazioni
type: system
tags: [prestazioni, ottimizzazione]
updated: 2026-10-20
sources: [scripts/world/World.gd, scripts/world/UnitView.gd, scripts/sim/Sim.gd]
---

# Prestazioni

Ottimizzazioni in ordine di impatto misurato (vedi [[benchmark]]):

1. **Loop delle animazioni impostati una volta sola**: prima a ogni morte si modificava un'Animation condivisa → tutti gli AnimationPlayer ricostruivano le cache (picchi 45–75 ms). Media 1% low: 28 → 45.
2. **Animazioni dei creep a 30 Hz, sospese fuori schermo**; viste del pool disattivate (`park`). Picchi da 7 a 1 per 15 s.
3. **Separazione senza allocazioni** (metà vicinato): da ~1 a ~0.5 ms per tick.
4. **Pool** di viste dei creep (pre-create all'avvio), proiettili, effetti, luci; **warmup** degli shader.
5. Minimappa a 10 Hz; barre e numeri in un solo overlay; IA a intervalli sfasati; griglia spaziale.
6. Ombre di creep e alberi solo in qualità Alta; FXAA invece di MSAA in Media; risoluzione 3D 75% in Bassa.

Profilazione integrata: `Game.prof_enabled` + `Game.prof_add()` (usati dal benchmark).
> [!warning] Il portatile di sviluppo (Alder Lake-UP4, 9 W) rallenta molto per calore e alimentazione: le misure variano anche del 30% tra prove identiche. Confrontare solo prove fatte in condizioni simili.
