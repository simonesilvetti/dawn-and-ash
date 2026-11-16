---
title: Test automatici
type: system
tags: [test, verifica]
updated: 2026-11-16
sources: [scripts/debug/AutoTest.gd, tools/net_tests.sh, tools/windows_tests.sh]
---

# Test automatici

Argomenti dopo `--` (vedi intestazione di `AutoTest.gd`):

| Comando | Cosa verifica |
|---|---|
| `godot --headless -- --autotest-training` | edifici, protezioni, acquisti, abilità di Kael (Q, E, W, R), last hit, XP, livelli, oro, torri, deny, assedio; poi un **Peppino** alleato comandato dal test (peer 99): modello, Carica (arrivo e stordimento), Fendente, Scudo di ferro (danno ridotto), Spaccaterra, attacco in mischia; morte/rinascita, vittoria, audio → `AUTOTEST OK`. Usa sempre Kael come eroe locale, qualunque sia la scelta salvata |
| `./tools/net_tests.sh [s]` | host+client locali con 0, 80, 150+jitter 30+3%, 250+5% ms, più un client con Peppino a 80 ms (verifica che l'host crei l'eroe scelto); poi client terminato a forza → `[OK]` ×6 |
| `./tools/windows_tests.sh [--no-shots]` | l'exe Windows sotto Wine (prefisso temporaneo): autotest, screenshot con la grafica, rete Linux↔Windows a 0 e 150 ms → `[OK]` ×5 (vedi [[build-e-distribuzione]]) |
| `godot -- --shots res://screenshots` | 10 screenshot + sequenze di animazione in un SubViewport 1600×900 |
| `godot -- --views <cartella> [--views-quality Q] [--views-fx] [--views-hero H]` | 7 inquadrature fisse (guado, corsia, riva, basi, torre, insieme) in ~6 s, per la revisione grafica; con `--views-fx` fotogrammi ravvicinati delle 4 abilità dell'eroe (`--views-hero peppino`: anche un primo piano `eroe.png` con l'HUD) |
| `godot --headless -- --duel [--duel-runs N] [--duel-level L] [--duel-noitems] [--duel-ban <eroe><slot>] [--duel-stats]` | duelli 1 contro 1 tra eroi in simulazione pura (~10 s): vittorie per livello e abilità andate a segno → [[bilanciamento]] |
| `godot -- --benchmark [--bench-preset N]` | scenario di carico per preset, picchi, profilo → `benchmark_results.md` |
| `godot --headless -- --soak --soak-minutes 30` | memoria, nodi, creep incastrati, tick massimo |
| `godot --headless -- --sim-smoke` | simulazione pura senza scena |

`--hero <id>` (qualsiasi modalità) sceglie l'eroe senza salvarlo. Watchdog (`--watchdog`, predefinito 900 s) per non restare bloccati. I test rendono deterministiche le verifiche fragili (deny su un creep appena nato, stordimento di qualsiasi nemico nell'area). → [[benchmark]], [[test-di-rete]], [[test-di-durata]]

Dalla Grafica v2 il benchmark stampa anche i tempi di rendering GPU/CPU per preset e accetta `--bench-preset Q` (un solo preset) e `--bench-at x,y` (inquadra un punto, es. `-75,75` = base della Lega). Vedi [[prestazioni]].

## Gorm (2026-11-16)
- `--autotest-training`: dopo Peppino un **Gorm** alleato (peer 98) con tre bersagli fermi, ondate sospese e gli altri
  eroi lontani: Fenditura (danno, stordimento, muro creato, unità spinte fuori, **il muro blocca** un eroe che prova ad
  attraversarlo e **viene aggirato** dalle estremità, sparisce dopo 5 s), passiva non lanciabile, Totem (balzo, arco
  del modello, scossa all'atterraggio, rune accese, danno potenziato esatto), Eco del sisma (colpo + echi).
- `tools/net_tests.sh`: caso `gorm_80ms`, in cui il client impara il Totem e lancia Fenditura e balzo: verifica che il
  muro arrivi al client e che il flag del totem carico (bit 256, flag a 16 bit) venga trasmesso.
- `--views --views-fx --views-hero gorm`: fotogrammi di Fenditura, Totem ed Eco con creep nemici vicini, più
  l'anteprima di mira (`mira_fenditura`).
- `--benchmark --bench-hero gorm`: lo scenario di carico lancia a ripetizione Fenditura, Totem ed Eco del sisma.
- `--duel`: coppie con Gorm, `--duel-pair`, `--duel-ban` multiplo, `DUEL_TRACE=1` (vedi [[bilanciamento]]).
