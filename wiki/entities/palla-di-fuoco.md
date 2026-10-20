---
title: Palla di fuoco (Q)
type: entity
tags: [abilità, fireball]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd, scripts/vfx/Vfx.gd]
---

# Palla di fuoco (Q)

Kael scaglia una sfera infuocata in linea retta (gittata 14, velocità 25 m/s). Esplode sul primo nemico non-edificio colpito o a fine corsa: danno magico 90/150/210/270 in 3 m. Effetti: sfera emissiva con scia, esplosione di particelle, anello e lampo di luce, leggera scossa della telecamera. In codice: proiettile lineare in `Sim._update_projectiles`, esplosione in `Sim._explode`.

Vedi anche [[abilita]], [[kael]], [[rendering-e-vfx]].
