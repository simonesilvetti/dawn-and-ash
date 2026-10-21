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
| `godot --headless -- --autotest-training` | edifici, protezioni, acquisti, abilità (Q, E, W, R), last hit, XP, livelli, oro, torri, deny, assedio, morte/rinascita, vittoria, audio → `AUTOTEST OK` |
| `./tools/net_tests.sh [s]` | host+client locali con 0, 80, 150+jitter 30+3%, 250+5% ms; poi client terminato a forza → `[OK]` ×5 |
| `godot -- --shots res://screenshots` | 10 screenshot + sequenze di animazione in un SubViewport 1600×900 |
| `godot -- --views <cartella> [--views-quality Q] [--views-fx]` | 7 inquadrature fisse (guado, corsia, riva, basi, torre, insieme) in ~6 s, per la revisione grafica; con `--views-fx` fotogrammi ravvicinati di onda d'urto, palla di fuoco, scatto e meteora |
| `godot -- --benchmark [--bench-preset N]` | scenario di carico per preset, picchi, profilo → `benchmark_results.md` |
| `godot --headless -- --soak --soak-minutes 30` | memoria, nodi, creep incastrati, tick massimo |
| `godot --headless -- --sim-smoke` | simulazione pura senza scena |

Watchdog (`--watchdog`, predefinito 900 s) per non restare bloccati. I test rendono deterministiche le verifiche fragili (deny su un creep appena nato, stordimento di qualsiasi nemico nell'area). → [[benchmark]], [[test-di-rete]], [[test-di-durata]]

Dalla Grafica v2 il benchmark stampa anche i tempi di rendering GPU/CPU per preset e accetta `--bench-preset Q` (un solo preset) e `--bench-at x,y` (inquadra un punto, es. `-75,75` = base della Lega). Vedi [[prestazioni]].
