---
title: Netcode
type: system
tags: [rete, multiplayer]
updated: 2026-10-20
sources: [scripts/autoload/Net.gd, scripts/world/World.gd, scripts/sim/Sim.gd]
---

# Netcode

## Trasporto
ENet (`ENetMultiplayerPeer`), 4 canali: 0 lobby (affidabile), 1 eventi e comandi (affidabile), 2 snapshot (non affidabile ordinato), 3 ping. Timeout di disconnessione 5–8 s. Massimo 1 avversario; controllo di versione all'ingresso.

## Server → client
- **Snapshot** a 30 Hz (ogni tick): intestazione per client (ultimo comando eseguito + tick), poi per unità `id u16, maschera u8` e solo i campi cambiati: posizione (i16 ×100, 1 cm), direzione u8, vita u16, mana u16, flag u8, massimi. Snapshot completo ogni 15 tick. Circa 8 KB/s in ingresso.
- **Eventi** affidabili per spawn/morte/proiettili/effetti; **stato degli eroi** (oro, XP, ricariche, oggetti) a 5 Hz.

## Client
- **Interpolazione** con 100 ms di ritardo; teletrasporti senza interpolazione; un'unità assente dagli snapshot più recenti è **ferma** (niente estrapolazione: era la causa di uno scatto di 0.93 m); estrapolazione massima 200 ms solo con pacchetti in ritardo.
- **Eventi** applicati al tempo di rendering, così animazioni e proiettili coincidono con le posizioni interpolate.
- **Predizione** del proprio eroe (movimento e inseguimento) con le stesse regole del server; **riconciliazione** esatta grazie all'ack: lo stato del tick T corrisponde all'istante locale `invio_comando + (T − tick_esecuzione + 1) · TICK`, indipendente da RTT e jitter; correzione morbida in ~150 ms, scatto oltre 3 m. Negli stati stabili (attacco, fermo) il client segue il server.
- **Ping** applicativo (passa dal simulatore di rete) e perdita mostrati nell'HUD.

## Simulatore di lag
`--netsim latency=MS,jitter=MS,loss=%` applica ritardi e perdite lato client (affidabili: in ordine, perdita = ritrasmissione). → [[test-di-rete]]

## Robustezza
RPC convalidati (solo tipi semplici, dimensione limitata); disconnessione dell'avversario = vittoria a tavolino; caduta dell'host = ritorno al menu con messaggio.
