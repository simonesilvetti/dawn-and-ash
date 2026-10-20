---
title: Test di durata (soak)
type: result
tags: [stabilità]
updated: 2026-10-20
sources: [scripts/debug/AutoTest.gd]
---

# Test di durata (soak)

Partita di allenamento di **30 minuti di gioco** accelerata 10× (112 s reali), con l'eroe che farma e lancia abilità.

- Nodi: 1807 → 1815 (stabili); memoria statica 109.2 → 110.4 MB (+1.1%).
- Nessun creep incastrato (fermo senza bersaglio) per più di 10 s; massimo 29 unità vive.
- Tick di simulazione massimo 1.0 ms. Nessun errore in console; uscita pulita (nessuna risorsa "ancora in uso").
