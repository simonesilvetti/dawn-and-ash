---
title: Panoramica del progetto
type: overview
tags: [progetto, stato]
updated: 2026-11-16
sources: [promt.md, README.md]
---

# Panoramica del progetto

**Dawn & Ash — Le Terre di Aethra** è un MOBA minimale in stile Dota 2, in 3D stilizzato (personaggi cartoon KayKit, terreno con texture CC0; vedi [[stile-grafico]] e [[piano-grafica-v2]]), fatto con Godot 4.7 e GDScript.
Si gioca su Linux e Windows in **allenamento** (un eroe contro creep e torri) oppure **1 contro 1 in rete**, con una macchina che fa da host.

## Stato attuale
- **Fase 1 (nucleo)**: completa, verificata dai test automatici. Vedi [[fasi-di-sviluppo]].
- **Fase 2 (arricchimento)**: completa: [[meteora]], creep d'assedio, deny, oggetti extra, musica di combattimento, nuvole, particelle, monete volanti, hit-stop.
- Prestazioni misurate su una GPU integrata Intel Iris Xe (chip da 9 W, a batteria): vedi [[benchmark]].
- Rete verificata con lag simulato fino a 250 ms e 5% di perdita: vedi [[test-di-rete]].
- **Tre eroi** da scegliere nel menu: [[kael]] (mago a distanza), [[peppino]] (guerriero corpo a corpo) e [[gorm]] (gigante che stordisce, dal 2026-11-16), bilanciati con duelli simulati (vedi [[bilanciamento]]).

## Mappa del wiki
- Gioco: [[kael]], [[peppino]], [[gorm]], [[lega-dell-alba]], [[culto-della-cenere]], [[creep]], [[edifici]], [[abilita]], [[oggetti]], [[controlli]].
- Idee: [[ambientazione]], [[stile-grafico]], [[bilanciamento]], [[fasi-di-sviluppo]], [[decisioni]].
- Software: [[architettura]], [[simulazione]], [[mappa]], [[netcode]], [[rendering-e-vfx]], [[animazioni]], [[interfaccia]], [[audio]], [[asset]], [[test-automatici]], [[prestazioni]], [[build-e-distribuzione]].
- Misure: [[benchmark]], [[test-di-rete]], [[test-di-durata]].
