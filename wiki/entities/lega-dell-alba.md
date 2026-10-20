---
title: Lega dell'Alba (Radiant)
type: entity
tags: [fazione]
updated: 2026-10-20
sources: [scripts/autoload/Game.gd, scripts/world/UnitView.gd]
---

# Lega dell'Alba (Radiant)

Cavalieri e maghi delle foreste dorate. Base in basso a sinistra della mappa (`MapData.BASE_CENTER[0]`). Colori: verde-acqua con dettagli dorati (`Game.TEAM_COLORS[0]`).

- Creep corpo a corpo: **Knight** con spada e scudo rotondo; a distanza: **Rogue incappucciato** con balestra; d'assedio: **Barbaro** che lancia rocce. → [[creep]]
- Edifici: torri e castello KayKit nella variante verde. → [[edifici]]
- In allenamento e come host il giocatore è sempre della Lega. In codice: `Game.Team.RADIANT`.
- Il lato della Lega della mappa è verde e rigoglioso (shader del terreno). → [[mappa]]
