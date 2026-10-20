# Ancients Clash — istruzioni per gli agenti (schema del wiki)

Questo progetto è un MOBA minimale in stile Dota 2 fatto con **Godot 4.7 + GDScript** (vedi `README.md`).
La conoscenza sul progetto è mantenuta in un **wiki persistente** secondo il pattern descritto in `llm-wiki.md`:
l'agente scrive e mantiene il wiki, l'utente lo legge (anche in Obsidian: la cartella `wiki/` è un vault valido).

## I tre livelli

1. **Fonti originali (immutabili)** — non si modificano mai:
   - `promt.md` — il prompt di progetto con tutti i requisiti;
   - `llm-wiki.md` — il pattern del wiki.
   Il codice in `scripts/` e i risultati in `benchmark_results.md` sono la "verità" su cui il wiki si basa.
2. **Il wiki** (`wiki/`) — pagine markdown scritte e mantenute dall'agente, collegate con `[[link]]` in stile Obsidian.
3. **Lo schema** — questo file.

## Struttura del wiki

```
wiki/
  index.md          catalogo di tutte le pagine (una riga di sintesi ciascuna) — leggerlo per primo
  log.md            registro cronologico, solo in aggiunta
  overview.md       panoramica del progetto e stato attuale
  sources/          una pagina di sintesi per ogni fonte originale
  entities/         cose del gioco: eroe, fazioni, unità, edifici, abilità, oggetti
  concepts/         idee trasversali: ambientazione, stile grafico, bilanciamento, fasi, decisioni
  systems/          come è fatto il software: architettura, simulazione, netcode, rendering, UI, audio, test, build
  results/          misure: benchmark, test di rete, test di durata
```

Ogni pagina inizia con un frontmatter YAML (utile con Dataview):

```yaml
---
title: Titolo leggibile
type: entity | concept | system | source | result | overview
tags: [tag1, tag2]
updated: AAAA-MM-GG
sources: [promt.md, scripts/sim/Sim.gd]
---
```

Convenzioni: italiano; frasi brevi; ogni pagina cita i file sorgente pertinenti (percorso `scripts/...`) e linka
le pagine correlate con `[[nome-pagina]]`; i numeri di bilanciamento si riportano **con la fonte** (`scripts/autoload/Game.gd`)
perché il codice è la verità; le contraddizioni tra pagine o tra wiki e codice si segnalano con `> [!warning]`.

## Flussi di lavoro

- **Dopo ogni modifica al codice** (ingest): aggiornare le pagine dei sistemi/entità toccati, aggiornare `wiki/index.md`
  se si aggiungono pagine, e aggiungere una voce in `wiki/log.md` nel formato
  `## [AAAA-MM-GG] tipo | titolo` (tipi: `ingest`, `modifica`, `test`, `benchmark`, `decisione`, `lint`, `query`).
- **Domande sul progetto** (query): leggere prima `wiki/index.md`, poi le pagine pertinenti, poi il codice se serve.
  Le risposte di valore (analisi, confronti) vanno salvate come nuove pagine del wiki.
- **Manutenzione** (lint, periodica): cercare contraddizioni, pagine orfane, affermazioni superate dal codice,
  concetti citati senza pagina; registrare l'esito in `log.md`.
- `DECISIONS.md` (radice) resta l'elenco ufficiale delle scelte prese in autonomia; `wiki/concepts/decisioni.md` lo riassume e linka.

## Regole di sviluppo

- Prima **fluido e stabile**, poi bello (vedi `wiki/concepts/fasi-di-sviluppo.md`). Dopo ogni modifica:
  `godot --headless --import` (nessun errore di script), `godot --headless -- --autotest-training` → `AUTOTEST OK`.
  Per modifiche di rete: `./tools/net_tests.sh`. Per modifiche grafiche/prestazioni: `godot -- --benchmark` e `godot -- --shots res://screenshots`.
- GDScript tipizzato, costanti di bilanciamento solo in `scripts/autoload/Game.gd`.
- La simulazione (`scripts/sim/`) non deve dipendere dalla scena; la grafica (`scripts/world/`, `scripts/vfx/`) non deve contenere logica di gioco.
- Commit git con messaggi in italiano.
