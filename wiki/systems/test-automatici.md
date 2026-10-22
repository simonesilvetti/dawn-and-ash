---
title: Test automatici
type: system
tags: [test, verifica]
updated: 2026-10-22
sources: [scripts/debug/AutoTest.gd, tools/net_tests.sh]
---

# Test automatici

Argomenti dopo `--` (vedi intestazione di `AutoTest.gd`):

| Comando | Cosa verifica |
|---|---|
| `godot --headless -- --autotest-training` | edifici, protezioni, acquisti, abilità di Kael (Q, E, W, R), last hit, XP, livelli, oro, torri, deny, assedio; poi un **Peppino** alleato comandato dal test (peer 99): modello, Carica (arrivo e stordimento), Fendente, Scudo di ferro (danno ridotto), Spaccaterra, attacco in mischia; morte/rinascita, vittoria, audio → `AUTOTEST OK`. Usa sempre Kael come eroe locale, qualunque sia la scelta salvata |
| `./tools/net_tests.sh [s]` | host+client locali con 0, 80, 150+jitter 30+3%, 250+5% ms, più un client con Peppino a 80 ms (verifica che l'host crei l'eroe scelto); poi client terminato a forza → `[OK]` ×6 |
| `godot -- --shots res://screenshots` | 10 screenshot + sequenze di animazione in un SubViewport 1600×900 |
| `godot -- --views <cartella> [--views-quality Q] [--views-fx] [--views-hero H]` | 7 inquadrature fisse (guado, corsia, riva, basi, torre, insieme) in ~6 s, per la revisione grafica; con `--views-fx` fotogrammi ravvicinati delle 4 abilità dell'eroe (`--views-hero peppino`: anche un primo piano `eroe.png` con l'HUD) |
| `godot --headless -- --duel [--duel-runs N] [--duel-level L] [--duel-noitems] [--duel-ban <eroe><slot>] [--duel-stats]` | duelli 1 contro 1 tra eroi in simulazione pura (~10 s): vittorie per livello e abilità andate a segno → [[bilanciamento]] |
| `godot -- --benchmark [--bench-preset N]` | scenario di carico per preset, picchi, profilo → `benchmark_results.md` |
| `godot --headless -- --soak --soak-minutes 30` | memoria, nodi, creep incastrati, tick massimo |
| `godot --headless -- --sim-smoke` | simulazione pura senza scena |

`--hero <id>` (qualsiasi modalità) sceglie l'eroe senza salvarlo. Watchdog (`--watchdog`, predefinito 900 s) per non restare bloccati. I test rendono deterministiche le verifiche fragili (deny su un creep appena nato, stordimento di qualsiasi nemico nell'area). → [[benchmark]], [[test-di-rete]], [[test-di-durata]]

Dalla Grafica v2 il benchmark stampa anche i tempi di rendering GPU/CPU per preset e accetta `--bench-preset Q` (un solo preset) e `--bench-at x,y` (inquadra un punto, es. `-75,75` = base della Lega). Vedi [[prestazioni]].
