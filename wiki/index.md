---
title: Indice del wiki
type: overview
tags: [indice]
updated: 2026-10-22
sources: []
---

# Indice del wiki

Catalogo di tutte le pagine. Leggere questo file per primo; la cronologia è in [[log]]. Schema e regole: `CLAUDE.md`.

## Panoramica

- [[overview]] — **Panoramica del progetto**: Dawn & Ash — Le Terre di Aethra è un MOBA minimale in stile Dota 2, in 3D low-poly cartoon, fatto con Godot 4.7 e GDScript.

## Fonti

- [[llm-wiki]] — **Fonte: llm-wiki.md (pattern del wiki)**: Descrive come mantenere una base di conoscenza con un LLM: invece di cercare ogni volta nei documenti grezzi (RAG),
- [[promt]] — **Fonte: promt.md (prompt di progetto)**: Il prompt originale, da eseguire in autonomia, senza domande, con le scelte annotate in DECISIONS.md.

## Entità del gioco

- [[abilita]] — **Abilità degli eroi**: tabella di Q/W/E/R di Kael con danni, mana e ricariche; regole di apprendimento e mira comuni a tutti gli eroi.
- [[creep]] — **Creep**: Ondata ogni 30 s (la prima a 5 s): 3 corpo a corpo + 1 a distanza per squadra; dalla 5ª ondata, ogni 5, anche un creep d'assedio (Fase 2).
- [[culto-della-cenere]] — **Culto della Cenere (Dire)**: Scheletri e creature nate dalle rovine bruciate. Base in alto a destra. Colori: rosso-viola (Game.TEAM_COLORS[1]).
- [[edifici]] — **Edifici: torri, Antico, fontana**: statistiche, protezione a cascata, aggro delle torri, fontana e negozio, crollo.
- [[kael]] — **Kael, il Piromante**: giovane mago a distanza della lega-dell-alba che doma il fuoco dei cristalli; uno dei due eroi selezionabili.
- [[lega-dell-alba]] — **Lega dell'Alba (Radiant)**: Cavalieri e maghi delle foreste dorate. Base in basso a sinistra della mappa (MapData.BASE_CENTER[0]). Colori: verde-acqua con dettagli...
- [[peppino]] — **Peppino, il Guerriero**: guerriero corpo a corpo con spada e scudo (modello Knight, elmo dorato); Fendente rotante, Carica, Scudo di ferro, Spaccaterra; bilanciato con Kael tramite duelli simulati.
- [[meteora]] — **Meteora (R, ultimate)**: Fase 2. Disponibile dal livello 6. Se il punto è oltre 16 m Kael cammina fino a gittata. Cerchio rosso di avviso, dopo 1 s cade un...
- [[oggetti]] — **Oggetti e negozio**: Negozio con il tasto B, utilizzabile entro 18 m dalla propria fontana. Massimo 6 oggetti. Vendita al 50% con click destro sull'oggetto.
- [[onda-d-urto]] — **Onda d'urto (E)**: Kael pianta il bastone a terra: anello di fuoco arcano di 5 m, danno magico 60/100/140/180 e rallentamento del 40% per 2 s. Effetti:...
- [[palla-di-fuoco]] — **Palla di fuoco (Q)**: Kael scaglia una sfera infuocata in linea retta (gittata 14, velocità 25 m/s). Esplode sul primo nemico non-edificio colpito o a fine...
- [[scatto]] — **Scatto (W)**: Teletrasporto istantaneo verso il punto indicato, limitato a 10 m e riportato dentro l'area percorribile. Effetti: sbuffo di braci alla...

## Concetti

- [[ambientazione]] — **Ambientazione: le Terre di Aethra**: Nelle Terre di Aethra due antichi cristalli, gli Antichi, alimentano due regni rivali: chi distrugge il cristallo nemico vince la guerra.
- [[bilanciamento]] — **Bilanciamento**: tutti i numeri stanno in scripts/autoload/Game.gd (eroi in Game.HEROES); formule; duelli simulati Kael–Peppino (`--duel`) e taratura.
- [[controlli]] — **Controlli**: tutti i comandi da tastiera e mouse in stile Dota.
- [[decisioni]] — **Decisioni prese in autonomia**: L'elenco completo e motivato è in DECISIONS.md (radice del progetto). Le più importanti:
- [[piano-grafica-v2]] — **Piano "Grafica v2"**: più dettaglio con Dota 2 come riferimento, stesse prestazioni: terreno con texture e rilievo, acqua, vegetazione, basi fortificate, effetti a strati, HUD ornato.
- [[fasi-di-sviluppo]] — **Fasi di sviluppo**: Principio: prima semplice, fluido e stabile — poi bello. Nessuna fase successiva finché i test della precedente non passano.
- [[stile-grafico]] — **Stile grafico**: stilizzato con texture (dalla v2): modelli KayKit su terreno con texture CC0, rilievo, acqua, molti dettagli. Visuale dall'alto inclinata di 50°.

## Sistemi software

- [[animazioni]] — **Animazioni**: Clip KayKit incluse nei .glb (76–95 per modello). Gestite con AnimationPlayer + blend (0.08–0.18 s).
- [[architettura]] — **Architettura del software**: 
- [[asset]] — **Asset e licenze**: Scaricati da tools/fetch_assets.sh (ripetibile, salta i file presenti). Licenze in assets/CREDITS.md.
- [[audio]] — **Audio**: - Bus: Master, Music, SFX, UI, con volumi nelle impostazioni; M silenzia la musica.
- [[build-e-distribuzione]] — **Build e distribuzione**: `build.sh` esporta gli eseguibili, crea l'installer `.run` per Linux e lo zip per Windows.
- [[interfaccia]] — **Interfaccia utente**: Tema comune (UiKit): pannelli scuri semitrasparenti con bordi dorati, angoli arrotondati.
- [[mappa]] — **Mappa e movimento**: Corsia diagonale unica da (−72, 72) a (72, −72), larga 30 m, con fiume perpendicolare al centro. Basi circolari di raggio 26 m negli angoli.
- [[netcode]] — **Netcode**: ## Trasporto
- [[prestazioni]] — **Prestazioni**: Ottimizzazioni in ordine di impatto misurato (vedi benchmark):
- [[rendering-e-vfx]] — **Rendering ed effetti**: ## Unità (UnitView)
- [[simulazione]] — **Simulazione (server autoritativo)**: Sim è un RefCounted con tick fisso (Game.TICK_RATE = 30 Hz). Ordine di un tick:
- [[test-automatici]] — **Test automatici**: Argomenti dopo -- (vedi intestazione di AutoTest.gd):

## Risultati

- [[benchmark]] — **Risultati dei benchmark**: Dati completi e cronologia in benchmark_results.md. Scenario: 5 ondate per lato al centro + abilità ripetute, 1600×900, VSync off.
- [[test-di-durata]] — **Test di durata (soak)**: Partita di allenamento di 30 minuti di gioco accelerata 10× (112 s reali), con l'eroe che farma e lancia abilità.
- [[test-di-rete]] — **Risultati dei test di rete**: Host e client sulla stessa macchina, 20–25 s di gioco, client che si muove e attacca.
