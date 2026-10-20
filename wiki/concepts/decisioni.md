---
title: Decisioni prese in autonomia
type: concept
tags: [decisioni]
updated: 2026-10-20
sources: [DECISIONS.md]
---

# Decisioni prese in autonomia

L'elenco completo e motivato è in `DECISIONS.md` (radice del progetto). Le più importanti:

- Godot 4.7.2 da pacman (installato dall'utente); template di esportazione: solo il file Linux estratto dall'archivio ufficiale con richieste HTTP Range.
- **Area percorribile convessa** (capsula della corsia ∪ cerchi delle basi) al posto della navmesh: le unità non si incastrano mai e il costo è minimo. → [[mappa]]
- **AnimationPlayer con blend** invece di AnimationTree: più semplice e leggero per decine di creep. → [[animazioni]]
- **Snapshot binari personalizzati** al posto di MultiplayerSynchronizer, con delta e ack dei comandi. → [[netcode]]
- Kael senza cappello per leggibilità dall'alto. → [[kael]]
- Barre della vita e numeri disegnati in un unico overlay 2D. → [[interfaccia]]
- Benchmark in un SubViewport 1600×900 a dimensione fissa (Hyprland ridimensiona le finestre). → [[test-automatici]]
