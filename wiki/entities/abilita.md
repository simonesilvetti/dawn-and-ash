---
title: Abilità degli eroi
type: entity
tags: [abilità]
updated: 2026-11-16
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd]
---

# Abilità degli eroi

Ogni eroe ha 4 abilità (Q, W, E, R) in `Game.HEROES[id].abilities`. Qui quelle di [[kael]]; quelle di [[peppino]] e [[gorm]] sono nelle loro pagine.

## Kael

| Tasto | Abilità | Bersaglio | Effetto | Mana | Ricarica |
|---|---|---|---|---|---|
| Q | [[palla-di-fuoco]] | direzione | proiettile, esplode sul primo nemico: 90/150/210/270 ad area 3 m | 80 | 6 s |
| W | [[scatto]] | punto | teletrasporto fino a 10 m | 60 | 14/12/10/8 s |
| E | [[onda-d-urto]] | attorno a sé | 60/100/140/180 in 5 m + rallentamento 40% per 2 s | 100 | 10 s |
| R | [[meteora]] | punto (16 m) | dopo 1 s: 300/450/600 in 6 m + stordimento 1.5 s | 200 | 60/50/40 s |

Fonte: `Game.HEROES.kael.abilities`. Le abilità infliggono **danno magico** (resistenza 25% sugli eroi) e **non colpiscono gli edifici** (vale anche per Peppino e Gorm).
Bersagli possibili: `dir`, `point`, `none` e, dal 2026-11-16, `passive` (abilità sempre attiva, non si lancia: la
Scossa di ritorno di Gorm).

## Regole
- 1 punto abilità per livello, più 1 all'inizio; Q parte già al livello 1.
- Livello richiesto (`Sim.required_level`): abilità base al livello `2n−1` per il livello n; R ai livelli 6, 8, 10.
- Si imparano con **Ctrl + tasto** o con il "+" sopra l'icona. Mana e ricarica si consumano al momento dell'effetto ("cast point").
- Mira: prima pressione mostra gittata e area, click sinistro lancia; opzione "lancio rapido" nelle impostazioni.
