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

## [2026-10-21] decisione | Grafica v2
L'utente trova la grafica troppo minimale e chiede più dettaglio (riferimento Dota 2) a parità di giocabilità, e un HUD migliore. Stile cambiato in "stilizzato con texture". Piano in [[piano-grafica-v2]]; decisioni in `DECISIONS.md`.

## [2026-10-21] modifica | Terreno, acqua, ambiente
`Terrain.gd` (rilievo visivo, alveo e guado), `ground.gdshader` con 6 texture ambientCG, `water.gdshader`, `Scenery.gd` (erba, fiori, cespugli, sassi, mura e villaggi delle basi, oggetti di scena, ponti, falò, bracieri, braci). Vedi [[mappa]], [[rendering-e-vfx]].

## [2026-10-21] benchmark | Import delle texture
Prima prova Media 46 FPS contro 70 della versione precedente: le texture erano importate senza compressione né mipmap. Con compressione VRAM e mipmap: 56–64 FPS; poi shader del terreno alleggerito. Il benchmark ora misura i tempi GPU (~14 ms/frame in Media). Vedi [[prestazioni]].

## [2026-10-21] modifica | Effetti e HUD
Effetti a strati, code continue, bruciature (Decal), muro di fiamme, scintille dei colpi. HUD ricostruito: `UiPanel`, icone a shader, ritratto 3D, negozio a schede, minimappa dal terreno vero. Vedi [[rendering-e-vfx]], [[interfaccia]].

## [2026-10-21] benchmark | Grafica v2: prestazioni da sistemare (lavoro sospeso)
A parità di calore: precedente 66–72 FPS in Media, v2 ~48–56. Costi GPU: erba ~3 ms (alleggerita dopo la misura), normal map del terreno ~1.7, acqua ~1.4 (caustiche ora solo in Alta), rilievo ~0.9. Autotest OK, rete 5/5 OK. Prossimi passi in [[piano-grafica-v2]].

## [2026-10-21] benchmark | A/B rinviato
Ripresa del confronto A/B in Media: macchina in uno stato lento (versione precedente 47 FPS invece di 87) e misure con ±10 FPS di rumore; v2 circa −18%. Interrotto su richiesta dell'utente (le finestre del benchmark disturbano): si riprende a macchina libera e scarica. Vedi [[piano-grafica-v2]].

## [2026-10-21] benchmark | Grafica v2: prestazioni alla pari
Profilo dei costi GPU con interruttori temporanei (poi rimossi): alberi ~4 ms, acqua ~2, rilievo ~1.8. Terreno e vegetazione divisi in blocchi con culling, acqua con mappa del fondo invece del depth buffer (resta in Alta). Media: GPU 21.2 → ~15–16 ms, 50–56 FPS contro 54–55 della versione precedente nella stessa sessione. Autotest OK. Vedi [[piano-grafica-v2]], [[rendering-e-vfx]].
