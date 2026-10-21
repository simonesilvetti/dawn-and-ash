---
title: Mappa e movimento
type: system
tags: [mappa, navigazione]
updated: 2026-10-21
sources: [scripts/sim/MapData.gd, scripts/world/MapBuilder.gd, scripts/world/Terrain.gd, scripts/world/Scenery.gd]
---

# Mappa e movimento

Corsia diagonale unica da (−72, 72) a (72, −72), larga 30 m, con fiume perpendicolare al centro. Basi circolari di raggio 26 m negli angoli.

## Area percorribile
`MapData.is_walkable` / `clamp_walkable`: capsula della corsia ∪ due cerchi. Sono forme convesse, quindi "muoviti dritto + proietta sul bordo" non incastra mai. Gli edifici respingono le unità lungo la tangente (scivolamento). Al posto della navmesh: vedi [[decisioni]].

## Costruzione visiva (`MapBuilder`)
Terreno a griglia 360×360 con **rilievo visivo** (`Terrain.gd`): argini di 2–4 m lungo la corsia, colline più lontano, piano attorno alle basi, alveo del fiume profondo 1.8 m con un **guado** di 0.42 m nella corsia. La simulazione resta sul piano: il rilievo è solo grafico (le unità nel guado scendono di quota). Shader con texture → [[rendering-e-vfx]].

Alberi in MultiMesh fuori dall'area percorribile, lontano dal fiume e dai villaggi (densità per preset), rocce lungo i bordi, montagne su un bordo quadrato a 146 m (a sud dietro la telecamera); caserme, tende, stendardi nelle basi; ninfee nel fiume. Dalla v2 (`Scenery.gd`): mura attorno alle basi con varco verso la corsia, villaggio dietro le mura, rovine e oggetti di scena ai bordi della corsia, due ponti in rovina, falò, erba e fiori.
