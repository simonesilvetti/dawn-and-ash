---
title: Kael, il Piromante
type: entity
tags: [eroe, personaggio]
updated: 2026-10-22
sources: [scripts/autoload/Game.gd, scripts/world/UnitView.gd, scripts/sim/HeroData.gd]
---

# Kael, il Piromante

Giovane mago della [[lega-dell-alba]] che ha imparato a domare il fuoco dei cristalli. Eroe a distanza; dal 2026-10-22 si può scegliere anche [[peppino]] (guerriero corpo a corpo), dal 2026-11-16 [[gorm]]. Entrambi gli eroi giocano per tutte e due le fazioni, con colori diversi.

## Aspetto
- Modello KayKit **Mage** (`assets/models/chars/Mage.glb`), scala 0.95, **senza cappello** (dall'alto il cappello copriva tutto il personaggio, vedi [[decisioni]]).
- Mantello arancio-rosso (Lega) o viola (Culto); **bastone con cristallo infuocato**: sfera emissiva, fiammella di particelle e luce, agganciate alla punta del bastone (`STAFF_TIP_Y` in `UnitView.gd`).
- Animazioni: Idle, Running_A, Spellcast_Shoot (attacco), Spellcast_Long/Raise (abilità), Death_A. → [[animazioni]]

## Statistiche (livello 1, +per livello) — fonte `Game.HEROES.kael`
| Vita | Rig. vita | Mana | Rig. mana | Danno | Intervallo attacco | Gittata | Velocità | Armatura |
|---|---|---|---|---|---|---|---|---|
| 600 (+80) | 2 (+0.2) | 300 (+40) | 1.5 (+0.15) | 45 (+4) | 1.3 s (−0.03, min 0.7) | 6 | 7 | 2 (+0.3) |

Resistenza magica 25%. Livello massimo 10, esperienza per livello `100 × livello`. Attacco base: dardo di fuoco (proiettile).

## Abilità
[[palla-di-fuoco]] (Q), [[scatto]] (W), [[onda-d-urto]] (E), [[meteora]] (R). Riepilogo in [[abilita]].

## Progressione
Oro, esperienza, punti abilità e oggetti sono in `HeroData` (`scripts/sim/HeroData.gd`). Vedi [[bilanciamento]] e [[oggetti]].
