---
title: Animazioni
type: system
tags: [animazioni]
updated: 2026-11-16
sources: [scripts/world/UnitView.gd]
---

# Animazioni

Clip KayKit incluse nei .glb (76–95 per modello). Gestite con **AnimationPlayer + blend** (0.08–0.18 s).

- **Sincronizzazione con la logica**: la velocità della clip d'attacco è scelta perché il "punto d'impatto" (≈45% della clip) coincida con `attack_point` (`play_attack`). La corsa si adatta alla velocità reale (`run_ref`).
- Muoversi interrompe l'animazione d'attacco (come in Dota). Clip di lancio distinte per le abilità. Scheletri: comparsa dal terreno e crollo.
- **Prestazioni**: i creep avanzano l'animazione a mano a 30 Hz (sfasati) e la sospendono fuori schermo; le viste nel pool sono disattivate (`park()`); i loop delle clip si impostano **una sola volta** per modello (modificare un'Animation condivisa costringeva tutti i player a ricostruire le cache: causava scatti). → [[prestazioni]]
- Verifica: sequenze di fotogrammi ravvicinati negli screenshot (`anim_camminata_*`, `anim_attacco_*`). → [[test-automatici]]

## Gorm (2026-11-16)
Clip del Barbarian: `2H_Melee_Idle`, `Running_A`, `2H_Melee_Attack_Slice` (attacco, impatto al 55%),
`2H_Melee_Attack_Chop` per Fenditura e Totem sul posto (colpo a terra al 57%: velocità 1.86 e 3.0, così coincide con il
cast point di 0.5 e 0.3 s), `Jump_Full_Short` per il balzo, accelerata perché duri quanto il volo (+0.35 s
d'atterraggio), `Death_B`. Il balzo solleva il modello lungo un arco parabolico (`UnitView.leap`): la posizione a terra
resta quella della simulazione. Scelte guardando un foglio di fotogrammi della clip. Vedi [[gorm]].
