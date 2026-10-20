---
title: Registro
type: overview
tags: [log]
updated: 2026-10-20
sources: []
---

# Registro

Cronologia, solo in aggiunta. Ultime voci: `grep "^## \[" wiki/log.md | tail -5`.

## [2026-10-20] ingest | promt.md e llm-wiki.md
Lette le due fonti; creato lo schema `CLAUDE.md` e la struttura del wiki. Pagine: [[promt]], [[llm-wiki]].

## [2026-10-20] decisione | Ambiente e asset
Godot 4.7.2 (pacman). Asset KayKit (personaggi animati, edifici, natura), Kenney (35 effetti), OpenGameArt (5 brani CC0) scaricati con `tools/fetch_assets.sh`. Vedi [[asset]].

## [2026-10-20] modifica | Fase 1 — simulazione e grafica
Scritti `Sim`, `Unit`, `HeroData`, `MapData`; `World`, `UnitView`, `MapBuilder`, `CameraRig`, `Vfx`; HUD, overlay, minimappa, menu, fine partita; `Net` con lobby e netsim; `AutoTest`. Vedi [[architettura]], [[simulazione]].

## [2026-10-20] test | Primo autotest dell'allenamento
Superato dopo due correzioni al test stesso (oro iniziale escluso dal conteggio; le lambda GDScript catturano per valore). Bot con logica di last hit. Vedi [[test-automatici]].

## [2026-10-20] modifica | Primo ciclo di revisione grafica
SubViewport fisso per gli screenshot (Hyprland ridimensionava la finestra), scroll ai bordi disattivato nei test, HUD a schermo intero (`set_anchors_and_offsets_preset`), telecamera a 50°, Kael senza cappello e più grande, mantelli per squadra, cristalli emissivi, scudi con bordo fresnel, montagne su bordo quadrato, fiamma sulla punta del bastone. Vedi [[stile-grafico]], [[kael]].

## [2026-10-20] benchmark | Baseline e ottimizzazioni
Baseline Media 88/43 FPS. Pool di viste e warmup degli effetti; animazioni dei creep a 30 Hz e sospese fuori schermo; separazione senza allocazioni; loop delle animazioni impostati una volta (causa dei picchi). Media 78/45. Vedi [[prestazioni]], [[benchmark]].

## [2026-10-20] test | Rete con lag simulato
Prima versione: errore 0.20–0.38 m, scatti creep 0.93 m. Fix: campioni al tempo di rendering, unità ferme non estrapolate, riconciliazione con ack dei comandi. Tutte le condizioni nei limiti; robustezza OK. Vedi [[netcode]], [[test-di-rete]].

## [2026-10-20] test | Soak test ed esportazione
30 minuti di gioco: memoria +1.1%, nessun creep incastrato. Esportato `build/AncientsClash.x86_64` (template Linux estratti via HTTP Range); l'eseguibile supera l'autotest. Uscita ordinata senza risorse in uso. Vedi [[test-di-durata]], [[build-e-distribuzione]].

## [2026-10-20] modifica | Fase 2
Meteora, creep d'assedio (Barbaro / Skeleton Minion che lanciano rocce), rafforzamento dei creep, deny, oggetti extra, crossfade musicale, hit-stop, ombre delle nuvole, particelle ambientali, monete volanti. Autotest esteso (3/3 OK), Media 90/65 FPS, rete 5/5 OK. Vedi [[fasi-di-sviluppo]].

## [2026-10-20] modifica | Secondo ciclo di revisione grafica
Barre degli edifici abbassate, meno rosa nella base del Culto (anelli e scudi più tenui), spicchio di ricarica ritagliato nell'icona, descrizioni del negozio accorciate.

## [2026-10-20] modifica | Cursore personalizzato
Spada rossa sui nemici e mirino durante la mira, disegnati via codice. Vedi [[interfaccia]].

## [2026-10-20] benchmark | Verifica finale
Bassa 124/67, Media 87/64, Alta 42/32 FPS (medio / 1% low). Test di rete finali (30 s): 5/5 OK. Vedi [[benchmark]], [[test-di-rete]].
