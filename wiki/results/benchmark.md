---
title: Risultati dei benchmark
type: result
tags: [benchmark, fps]
updated: 2026-11-16
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
| Grafica v2, macchina fresca (2026-10-21 notte) | Bassa | 135 | 68 | 25.9 ms |
| Grafica v2, macchina fresca | Media | 87 | 63 | 23.5 ms |
| Grafica v2, macchina fresca | Alta | 46 | 41 | 25.7 ms |
| Grafica v2, base della Lega (`--bench-at -75,75`) | Media | 101 | 62 | 20.9 ms |
| **Grafica v2 rifinita** (notte) | Bassa | 133 | 73 | 19.6 ms |
| **Grafica v2 rifinita** | Media | 83 | 64 | 21.2 ms |
| **Grafica v2 rifinita** | Alta | 44 | 35 | 30.4 ms |
| Peppino + nuova console (A/B con `9e0e222`: 86 / 61) | Media | 84 | 62 | 22.2 ms |
| Gorm, A/B con `1ea3f01` a CPU carica (vedi nota) | Media | 22 | 9 | — |

GPU in Media ~10.6 ms/frame (riferimento della notte). A portatile fresco, alimentato e in profilo "performance" la
v2 è alla pari o sopra la versione finale precedente in tutti i preset: le misure lente del pomeriggio del 2026-10-21
dipendevano dallo stato della macchina. Dopo la rifinitura della notte: GPU in Media ~11.1 ms
(+0.5 ms). Nella base, con la CPU rallentata, A/B con il commit di partenza alla pari entro il rumore.

Limiti (Media): FPS medio ≥ 60, 1% low ≥ 45, tick < 4 ms, draw call < 1000 → rispettati. L'**Alta** resta sui 40 FPS su questo chip: è pensata per GPU dedicate. Vedi [[prestazioni]].

Console ornata, alloggiamenti e barre a shader (2026-10-22): +0.17 ms di GPU in Media (11.0 contro 10.85 ms), nel margine.

> [!note] Gorm (2026-11-16): misure fatte con un altro programma che occupava tutta la CPU (8 processi), quindi i
> valori assoluti non valgono e non sono stati scritti in `benchmark_results.md`. A/B alternato nelle stesse condizioni
> (Media, 15 s): commit di partenza 21 e 23 FPS (GPU 21.7 e 24.0 ms), versione nuova 22 FPS (GPU 22.0 ms), scenario con
> le abilità di Gorm a ripetizione (`--bench-hero gorm`: muri, balzi, echi ogni 0.7 s) 23 e 22 FPS (GPU 24.3 e 22.8 ms).
> Nessuna differenza oltre il rumore. Da ripetere a macchina scarica.
