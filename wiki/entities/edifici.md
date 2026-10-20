---
title: Edifici: torri, Antico, fontana
type: entity
tags: [edifici, torri]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd, scripts/world/UnitView.gd]
---

# Edifici: torri, Antico, fontana

| Edificio | Vita | Armatura | Danno | Intervallo | Gittata | Modello KayKit |
|---|---|---|---|---|---|---|
| Torre T1 | 1800 | 10 | 110 | 1.0 s | 8 | building_tower_A |
| Torre T2 | 2200 | 12 | 140 | 1.0 s | 8 | building_tower_B |
| Antico | 4000 | 15 | — | — | — | building_castle |
| Fontana | invulnerabile | — | 300 | 0.3 s | 10 | building_well |

Fonte: `Game.BUILDINGS`, posizioni in `MapData` (T1 a ±27, T2 a ±52, Antico a ±70, fontana a ±88 lungo la diagonale).

## Regole
- **Protezione a cascata**: la T2 è invulnerabile finché c'è la T1; l'Antico finché c'è la T2 (`Sim._update_invulnerability`). Si vede con uno scudo trasparente e la scritta INVULNERABILE.
- **Aggro delle torri** (regola Dota): se un eroe nemico attacca un nostro eroe nel raggio della torre, la torre lo prende di mira (`last_hero_attack_time`).
- La **fontana** rigenera il 5% al secondo di vita e mana degli alleati entro 12 m e fa da negozio (entro 18 m).
- Torre distrutta: 200 oro a tutti gli eroi nemici, 150 XP, esplosione, crollo e macerie. **Antico distrutto = fine partita** (al rallentatore in allenamento).

## Grafica
Cristallo emissivo rotante sopra torri e Antico, luce che "respira" sull'Antico, zampillo luminoso sulla fontana. → [[rendering-e-vfx]]
