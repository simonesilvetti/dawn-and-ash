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

## [2026-10-21] benchmark | Riferimento a macchina fresca
Portatile alimentato, freddo, profilo "performance": Bassa 135/68, Media 87/63, Alta 46/41; base della Lega in Media 101/62. La v2 è nei limiti e sopra la versione finale precedente. Vedi [[benchmark]].

## [2026-10-21] modifica | Rifinitura grafica (notte)
Nuova modalità `--views` (inquadrature fisse, `--views-fx` per le abilità) per iterare in fretta. Acqua con scie, scintillii e schiuma a due fasce; increspature nel guado (`wake.gdshader`); alberi con tinta per istanza (il primo hash dava quasi sempre lo stesso valore); occlusione finta con uniforme globale `occ_tex`; sentiero senza righe di ripetizione, tracce e orlo; piazze vissute; braci nel Culto; cristalli a gemma; muro di fiamme e grandi esplosioni corretti. Provati AgX/ACES e fiamme opache: scartati. Vedi [[rendering-e-vfx]], [[piano-grafica-v2]].

## [2026-10-21] test | Verifica finale della notte
Autotest OK, rete 5/5 OK. Benchmark: Bassa 133/73, Media 83/64, Alta 44/35. Nella base la CPU era rallentata (tick 1.9 ms): A/B con `7089eca` nelle stesse condizioni alla pari (GPU +0.2 ms). Vedi [[benchmark]].

## [2026-10-21] test | Soak dopo la rifinitura
Partita accelerata: nodi 2816 → 2858, memoria 181.7 → 183.9 MB, nessun creep incastrato, tick max 0.65 ms: SOAK OK. Le increspature del guado non accumulano nodi. Distruzione dell'Antico con esplosioni scaglionate; in Bassa l'acqua senza scie e scintillii. Vedi [[test-di-durata]], [[rendering-e-vfx]].

## [2026-10-22] modifica | Negozio apribile col mouse
Il negozio non ha un edificio e si apriva solo con B. Aggiunti il pulsante "Negozio (B)" accanto all'oro nell'HUD (`scripts/ui/Hud.gd`) e il click sinistro sulla propria fontana (`scripts/world/World.gd`). Autotest OK. Vedi [[oggetti]].

## [2026-10-22] ingest | Nuovo eroe Peppino, console curata, nuovo cursore
Richiesta dell'utente: cursore d'attacco meno retrò, un eroe corpo a corpo "Peppino" con spada e scudo forte come
Kael, console di gioco più curata (riferimento Dota 2, stessi elementi e posizioni).
- Dati degli eroi in `Game.HEROES` (Kael e Peppino), scelta nel menu (`settings.hero`), in rete nel saluto del client.
- [[peppino]]: modello Knight con elmo dorato e scudo a goccia; Fendente rotante, Carica (scatto con stordimento),
  Scudo di ferro (riduzione danni), Spaccaterra (crepa in linea). Nuovi effetti, icone a shader, suoni esistenti.
- Strumento `--duel` per i duelli simulati; taratura di Peppino fino a 40–40, 48–32, 40–40, 44–36 (vedi [[bilanciamento]]).
- Console: `console.gdshader`, `slot.gdshader`, `bar.gdshader`, ritratto e tacche rifatti (vedi [[interfaccia]]).
- Cursori `Cursors.gd`: spada e mirino antialias.

## [2026-10-22] test | Verifica di Peppino e della nuova console
Autotest OK (con la nuova sezione su Peppino); test di rete 6/6 OK, compreso un client con Peppino (vedi
[[test-di-rete]]); A/B in Media: 84 FPS contro 86, +0.17 ms di GPU (vedi [[benchmark]]). Screenshot e `--views-fx`
di Peppino controllati.

## [2026-10-22] decisione | Il gioco si chiama Dawn & Ash
Scelta dell'utente: il titolo *Ancients Clash* diventa **Dawn & Ash** (dalle due fazioni, Lega dell'Alba e Culto della
Cenere); il sottotitolo *Le Terre di Aethra* resta. Cambiati il menu, `project.godot`, l'eseguibile (`DawnAndAsh.x86_64`),
README, CLAUDE.md e wiki. Le impostazioni ora stanno in `~/.local/share/dawn-and-ash/` (quelle vecchie non vengono migrate).
`promt.md` resta immutato.

## [2026-10-22] ingest | Installer per Linux
`tools/make_installer.sh` (chiamato da `build.sh`) crea l'installer autoestraente `DawnAndAsh-0.1.0-linux-x86_64.run`
(vedi [[build-e-distribuzione]]): preferito a Flatpak e AppImage perché non richiede niente all'utente. Autotest OK dal
progetto e dal binario installato; installazione e disinstallazione provate in una home finta.

## [2026-10-22] modifica | Schermata Informazioni e identificativo com.atomicgrove.dawnandash
Regola dell'utente per tutti i suoi programmi: identificativo `com.atomicgrove.<nome>` e una schermata di informazioni
con autore Simone Silvetti e sito simonesilvetti.com. Costanti `APP_ID`, `AUTHOR`, `WEBSITE` in `scripts/autoload/Game.gd`;
pulsante "Informazioni" nel menu (vedi [[interfaccia]]); l'installer usa l'identificativo per `.desktop` e icona
(vedi [[build-e-distribuzione]]). Nuovo screenshot `01b_informazioni` in `--shots`.

## [2026-10-22] test | Test della Meteora reso stabile
L'autotest falliva circa una volta su cinque su "Meteora: stordimento dei nemici colpiti": la Meteora a volte uccideva
il creep bersaglio, e un morto non risulta stordito. Ora il test dà al bersaglio 5000 di vita; 6 esecuzioni su 6 OK
(vedi [[test-automatici]]).

## [2026-10-22] decisione | Licenza GPL-3.0-or-later e repository pubblico
Scelte dell'utente: codice con licenza GNU GPL v3.0 o successiva (`LICENSE`, README, schermata Informazioni);
repository pubblico GitHub `dawn-and-ash`, installer `.run` allegato alla Release v0.1.0
(vedi [[build-e-distribuzione]]). Tolto dal README l'IP d'esempio: la schermata "Ospita" mostra già gli IP locali.


## [2026-10-26] modifica | Build per Windows
Richiesta dell'utente: distribuire il gioco anche agli utenti Windows. Nuovo preset "Windows Desktop" in
`export_presets.cfg`, esportato da Linux; `build.sh` costruisce entrambe le piattaforme (o una sola con
`./build.sh linux|windows`); `tools/fetch_templates.py` accetta le piattaforme; `tools/make_windows_zip.sh` crea lo zip
con exe, licenza e LEGGIMI. Icona `icon.ico` e metadati scritti da Godot senza rcedit (vedi [[build-e-distribuzione]]).
Import e autotest OK; l'exe non è ancora stato provato su Windows.

## [2026-10-26] decisione | Versione 0.2.0 e Release con la build Windows
Versione portata a 0.2.0 (`project.godot`, `Game.VERSION`) per la nuova Release GitHub v0.2.0, che allega l'installer
`.run` e l'eseguibile Linux più lo zip Windows (vedi [[build-e-distribuzione]]). Il saluto di rete confronta
`Game.VERSION` (`scripts/autoload/Net.gd`): giocatori 0.1.0 e 0.2.0 non possono giocare insieme in rete.

## [2026-10-26] test | Build Windows provata con Wine
Nuovo `tools/windows_tests.sh`: l'exe Windows sotto Wine 11.17 (prefisso temporaneo) supera l'autotest, produce i 24
screenshot con Vulkan identici a quelli Linux e gioca in rete con la versione Linux in tutte e due le direzioni, anche
con lag (vedi [[test-di-rete]], [[build-e-distribuzione]]). Restano da provare su Windows vero SmartScreen, firewall e driver.

## [2026-11-16] ingest | Nuovo eroe Gorm, lo Scuotiterra
Richiesta dell'utente: un nuovo personaggio che stordisce, ispirato all'Earthshaker di Dota 2, fatto bene, con
animazioni carine e leggere. [[gorm]]: modello Barbarian con un totem costruito da primitive (rune che si accendono);
Fenditura (danno, stordimento e **muro di roccia** che blocca il passaggio per 5 s), Totem del sisma (balzo, colpo
potenziato), Scossa di ritorno (**passiva**: ogni abilità stordisce attorno), Eco del sisma (danno + echi).
- Simulazione: muri con spinta e aggiramento (`MapData.push_from_wall`, `MapData.wall_detour`), balzo sopra i muri,
  attacco potenziato, abilità passive, effetti ritardati generalizzati (vedi [[simulazione]]).
- Rete: flag degli snapshot a 16 bit, muri nella predizione del client, versione 0.3.0 (vedi [[netcode]]).
- Grafica: rocce che emergono e sprofondano, onda sismica, stelline dello stordimento per tutte le unità, anteprima di
  mira in linea; icone procedurali nuove; menu con tre schede (vedi [[rendering-e-vfx]], [[interfaccia]]).
- Due versioni dell'aggiramento dei muri non funzionavano (scivolamento con minimo locale a metà muro; tappa sull'asse
  del muro dalla quale la meta restava coperta dalla punta); la terza punta all'angolo dal lato della meta.

## [2026-11-16] test | Verifica di Gorm
Import senza errori; autotest OK (sezione nuova su Gorm); test di rete OK compreso `gorm_80ms`, tranne la robustezza,
che fallisce anche sul commit di partenza (vedi [[test-di-rete]]). Benchmark solo A/B a CPU carica: nessuna differenza
oltre il rumore (vedi [[benchmark]]). Taratura con i duelli e squilibri rimasti in [[bilanciamento]].

## [2026-11-16] modifica | Taratura dei tre eroi
Richiesta dell'utente: rendere gli eroi più equilibrati. Trovato un errore nei duelli simulati: la T1 della Lega, a
~10 m dal duello, sparava a chi combatteva contro l'eroe della Lega; ora le torri nei duelli non sparano. Nuova misura
(scarto medio di vita) accanto alle vittorie. Ritoccati Kael (più vita), Peppino (più mana, Fendente più economico,
meno vita per livello) e Gorm (vedi [[bilanciamento]]); IA dei duelli di Gorm che tiene il balzo contro lo Scatto.
Scarto entro ±8% in tutte le 12 combinazioni; autotest OK.
