---
title: Fonte: promt.md (prompt di progetto)
type: source
tags: [fonte, requisiti]
updated: 2026-10-20
sources: [promt.md]
---

# Fonte: promt.md (prompt di progetto)

Il prompt originale, da eseguire **in autonomia, senza domande**, con le scelte annotate in `DECISIONS.md`.

## Punti chiave
- Godot 4 stable + GDScript tipizzato; Linux; progetto in `/home/simone/Work/game`.
- Modalità: **Allenamento** (priorità assoluta) e **1 contro 1 in rete** (host/client ENet). → [[netcode]]
- Principio guida (sez. 0.2): prima **semplice, fluido e stabile**, poi bello; due fasi. → [[fasi-di-sviluppo]]
- Ambientazione (sez. 0.1): Terre di Aethra, Lega dell'Alba contro Culto della Cenere, eroe **Kael, il Piromante**. → [[ambientazione]], [[kael]]
- Stile (sez. 3): 3D low-poly cartoon, KayKit come fonte unica dei modelli, animazioni vere, musica ed effetti sonori. → [[stile-grafico]], [[animazioni]], [[audio]]
  > [!warning] Superato dalla Grafica v2 (2026-10-21): terreno con texture CC0 ambientCG, su richiesta dell'utente. Vedi [[piano-grafica-v2]].
- Bilanciamento (sez. 5) con valori iniziali per eroe, abilità, creep, edifici, oggetti. → [[bilanciamento]]
- Controlli stile Dota (sez. 6), telecamera (sez. 7), interfaccia (sez. 8). → [[controlli]], [[interfaccia]]
- Netcode anti-lag (sez. 10.4) e prestazioni/stabilità (sez. 10.5). → [[netcode]], [[prestazioni]]
- Verifica automatica (sez. 11): autotest, test di rete con lag, screenshot, benchmark, soak test, esportazione. → [[test-automatici]]
- Criteri di completamento (sez. 12). Lo stato di ciascuno è in [[overview]] e in `DECISIONS.md`.
