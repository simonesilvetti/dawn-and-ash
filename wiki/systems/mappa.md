---
title: Mappa e movimento
type: system
tags: [mappa, navigazione]
updated: 2026-10-20
sources: [scripts/sim/MapData.gd, scripts/world/MapBuilder.gd]
---

# Mappa e movimento

Corsia diagonale unica da (−72, 72) a (72, −72), larga 30 m, con fiume perpendicolare al centro. Basi circolari di raggio 26 m negli angoli.

## Area percorribile
`MapData.is_walkable` / `clamp_walkable`: capsula della corsia ∪ due cerchi. Sono forme convesse, quindi "muoviti dritto + proietta sul bordo" non incastra mai. Gli edifici respingono le unità lungo la tangente (scivolamento). Al posto della navmesh: vedi [[decisioni]].

## Costruzione visiva (`MapBuilder`)
Terreno 380×380 con shader procedurale; alberi in MultiMesh fuori dall'area percorribile (densità per preset), rocce lungo i bordi, montagne su un bordo quadrato a 146 m (a sud dietro la telecamera); caserme, tende, stendardi nelle basi; ninfee nel fiume.
