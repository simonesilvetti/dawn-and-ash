# Risultati dei benchmark

Scenario: 5 ondate per lato contemporaneamente al centro della mappa + abilità lanciate a ripetizione, telecamera sullo scontro, VSync disattivato.
Limiti (preset Media): FPS medio ≥ 60, 1% low ≥ 45, tick di simulazione < 4 ms, draw call < 1000.

## 2026-10-20T19:41:59 baseline Fase 1

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600.0, 3524.0) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 120 | 50 | 47.7 | 1162 | 491 | 57 | 117 |
| Media | 88 | 43 | 42.5 | 1131 | 478 | 58 | 117 |
| Alta | 41 | 24 | 54.4 | 2030 | 1197 | 51 | 116 |

## 2026-10-20T19:43:48 pool modelli + warmup effetti

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600.0, 1743.0) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 95 | 43 | 29.6 | 1513 | 483 | 57 | 119 |
| Media | 60 | 22 | 69.6 | 2681 | 477 | 58 | 122 |
| Alta | 40 | 17 | 86.3 | 2915 | 1190 | 57 | 123 |

## 2026-10-20T19:45:12 viste nel pool disattivate

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 89 | 39 | 44.1 | 1803 | 498 | 51 | 119 |
| Media | 61 | 22 | 66.6 | 2700 | 490 | 50 | 121 |
| Alta | 39 | 16 | 85.1 | 2895 | 1168 | 57 | 122 |

## 2026-10-20T19:46:02 diagnostica picchi

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1667.0, 900.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 72 | 30 | 40.3 | 1739 | 528 | 50 | 119 |

## 2026-10-20T19:46:31 A/B senza abilità

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 68 | 31 | 40.7 | 2584 | 558 | 49 | 118 |

## 2026-10-20T19:47:04 diagnostica CPU

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 69 | 30 | 50.6 | 2178 | 559 | 49 | 118 |

## 2026-10-20T19:47:45 profilo

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 74 | 34 | 39.6 | 1889 | 559 | 49 | 118 |

## 2026-10-20T19:48:30 animazioni a 30Hz + LOD

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 78 | 38 | 36.8 | 1960 | 559 | 49 | 118 |

## 2026-10-20T19:49:01 profilo sim

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 10 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 110 | 50 | 25.0 | 1678 | 566 | 54 | 115 |

## 2026-10-20T19:49:36 separazione ottimizzata

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 10 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 115 | 53 | 29.3 | 1232 | 565 | 52 | 115 |

## 2026-10-20T19:51:21 dopo ottimizzazioni CPU

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1681.0, 900.0) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 104 | 49 | 28.3 | 1440 | 505 | 58 | 118 |
| Media | 69 | 28 | 57.1 | 2238 | 495 | 51 | 120 |
| Alta | 40 | 23 | 74.8 | 2279 | 1219 | 50 | 120 |

## 2026-10-20T19:52:10 loop animazioni configurati una volta

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600.0, 1743.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 78 | 45 | 27.6 | 1619 | 498 | 52 | 119 |

## 2026-10-20T20:16:09 Fase 2 completa

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600.0, 1743.0) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 90 | 65 | 17.8 | 1032 | 529 | 54 | 130 |
