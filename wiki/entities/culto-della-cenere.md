---
title: Culto della Cenere (Dire)
type: entity
tags: [fazione]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/world/UnitView.gd]
---

# Culto della Cenere (Dire)

Scheletri e creature nate dalle rovine bruciate. Base in alto a destra. Colori: rosso-viola (`Game.TEAM_COLORS[1]`).

- Creep: **Skeleton Warrior** con lama e scudo, **Skeleton Mage** con bastone, **Skeleton Minion** grande come creep d'assedio. Gli scheletri **emergono dal terreno** alla nascita (`Spawn_Ground_Skeletons`) e **crollano** alla morte (`Death_C_Skeletons`). → [[creep]], [[animazioni]]
- Edifici in variante rossa. Il loro lato della mappa, oltre il fiume, sfuma verso cenere e alberi bruniti.
- Nel 1 contro 1 è la squadra del client. In codice: `Game.Team.DIRE`.
