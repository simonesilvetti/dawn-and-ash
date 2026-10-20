---
title: Scatto (W)
type: entity
tags: [abilità, blink]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd, scripts/vfx/Vfx.gd]
---

# Scatto (W)

Teletrasporto istantaneo verso il punto indicato, limitato a 10 m e riportato dentro l'area percorribile. Effetti: sbuffo di braci alla partenza, vortice di fiamme all'arrivo. Sul client il teletrasporto azzera interpolazione e predizione per evitare scie (`World._ev_fx`).

Vedi anche [[abilita]], [[kael]], [[rendering-e-vfx]].
