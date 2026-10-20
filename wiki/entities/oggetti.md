---
title: Oggetti e negozio
type: entity
tags: [oggetti, negozio]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd, scripts/ui/Hud.gd]
---

# Oggetti e negozio

Negozio con il tasto **B**, utilizzabile entro 18 m dalla propria fontana. Massimo 6 oggetti. Vendita al 50% con click destro sull'oggetto.

| Oggetto | Costo | Effetto | Fase |
|---|---|---|---|
| Spada lunga | 400 | +15 danno | 1 |
| Armatura di cuoio | 350 | +4 armatura | 1 |
| Stivali della velocità | 450 | +1.5 velocità | 1 |
| Gemma della vitalità | 500 | +250 vita | 1 |
| Pozione di cura | 100 | 400 vita in 8 s, interrotta dai danni degli eroi (tasti 1–6) | 1 |
| Cristallo arcano | 500 | +200 mana, +1 rig. mana | 2 |
| Anello di rigenerazione | 300 | +4 rig. vita | 2 |
| Pozione di mana | 100 | 250 mana in 8 s | 2 |
| Lama del vampiro | 1200 | +20 danno, 15% rubavita sugli attacchi | 2 |

Fonte: `Game.ITEMS`. Oro iniziale 600, +1 oro/s. Le statistiche si ricalcolano in `HeroData.apply_stats`.
