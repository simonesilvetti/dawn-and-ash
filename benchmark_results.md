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

## 2026-10-20T20:29:21 FINALE (Fase 1 + Fase 2)

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 25 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 124 | 67 | 18.9 | 1047 | 504 | 56 | 133 |
| Media | 87 | 64 | 25.0 | 969 | 519 | 58 | 135 |
| Alta | 42 | 32 | 35.0 | 1710 | 1246 | 57 | 135 |

## 2026-10-21T13:57:22 Grafica v2

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 92 | 50 | 26.9 | 1628 | 559 | 51 | 155 |
| Media | 54 | 34 | 37.6 | 2361 | 606 | 52 | 170 |
| Alta | 30 | 23 | 53.2 | 2344 | 1380 | 52 | 179 |

## 2026-10-21T13:57:42 Grafica v2, base della Lega

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 59 | 28 | 47.5 | 2506 | 359 | 53 | 164 |

> Nota (2026-10-21): le due misure "Grafica v2" qui sopra sono state fatte con il portatile molto caldo (tick sim
> 2.4 ms invece di ~1 ms) e prima dell'alleggerimento dell'erba. Nelle stesse condizioni la versione precedente faceva
> ~66–72 FPS in Media. Da rifare a portatile freddo con il confronto A/B (vedi wiki/concepts/piano-grafica-v2.md).

## 2026-10-21T23:14:12 notte: riferimento

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 135 | 68 | 25.9 | 1013 | 530 | 51 | 161 |
| Media | 87 | 63 | 23.5 | 997 | 591 | 51 | 175 |
| Alta | 46 | 41 | 25.7 | 994 | 1509 | 52 | 187 |

## 2026-10-21T23:14:37 notte: riferimento, base della Lega

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 101 | 62 | 20.9 | 990 | 349 | 52 | 167 |

## 2026-10-21T23:41:22 notte: finale (grafica v2 rifinita)

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 20 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Bassa | 133 | 73 | 19.6 | 1034 | 530 | 51 | 180 |
| Media | 83 | 64 | 21.2 | 998 | 617 | 52 | 192 |
| Alta | 44 | 35 | 30.4 | 1254 | 1546 | 52 | 204 |

## 2026-10-21T23:42:09 notte: finale, base della Lega

GPU: Intel(R) Iris(R) Xe Graphics (ADL GT2) · risoluzione (1600, 900) · durata 15 s per preset

| Preset | FPS medio | 1% low | Frame max (ms) | Tick sim (µs) | Draw call | Unità | Memoria (MB) |
|---|---|---|---|---|---|---|---|
| Media | 80 | 38 | 35.7 | 1941 | 345 | 53 | 186 |

> Nota (2026-10-21 notte): la misura "finale, base della Lega" è stata fatta con la CPU rallentata (tick sim ~1.9 ms
> invece di ~1). A/B nelle stesse condizioni, base della Lega, Media, 15 s: commit di partenza `7089eca` 80 e 77 FPS
> (GPU 9.5–9.6 ms), versione finale 74 e 74 FPS (GPU 9.8 ms). Differenza di GPU ~0.2 ms, nel rumore.

> Nota (2026-10-22): Peppino, nuova console e cursori. A/B nelle stesse condizioni (Media, 20 s, centro): versione
> nuova 84 e 84 FPS (GPU 11.03 e 11.01 ms), commit di partenza `9e0e222` 86 FPS (GPU 10.85 ms). Costo degli shader
> della console (alloggiamenti, cornice, barre) ~0.17 ms di GPU.
