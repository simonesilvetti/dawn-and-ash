---
title: Risultati dei benchmark
type: result
tags: [benchmark, fps]
updated: 2026-10-20
sources: [benchmark_results.md]
---

# Risultati dei benchmark

Dati completi e cronologia in `benchmark_results.md`. Scenario: 5 ondate per lato al centro + abilità ripetute, 1600×900, VSync off.
Macchina: Intel Iris Xe (Alder Lake-UP4, 9 W), spesso a batteria.

| Momento | Preset | FPS medio | 1% low | Frame max |
|---|---|---|---|---|
| Baseline Fase 1 | Media | 88 | 43 | 42.5 ms |
| Dopo animazioni 30 Hz | Media | 78 | 38 | 36.8 ms |
| Dopo fix loop animazioni | Media | 78 | 45 | 27.6 ms |
| Fase 2 completa | Media | 90 | 65 | 17.8 ms |
| **Finale** | Bassa | 124 | 67 | 18.9 ms |
| **Finale** | Media | 87 | 64 | 25.0 ms |
| **Finale** | Alta | 42 | 32 | 35.0 ms |

Limiti (Media): FPS medio ≥ 60, 1% low ≥ 45, tick < 4 ms, draw call < 1000 → rispettati. L'**Alta** resta sui 40 FPS su questo chip: è pensata per GPU dedicate. Vedi [[prestazioni]].
