---
title: Fonte: llm-wiki.md (pattern del wiki)
type: source
tags: [fonte, metodo]
updated: 2026-10-20
sources: [llm-wiki.md]
---

# Fonte: llm-wiki.md (pattern del wiki)

Descrive come mantenere una base di conoscenza con un LLM: invece di cercare ogni volta nei documenti grezzi (RAG),
l'agente **costruisce e mantiene un wiki persistente** di pagine markdown collegate.

## Come è applicato qui
- **Fonti grezze**: `promt.md`, `llm-wiki.md` (immutabili). Il codice è la verità tecnica.
- **Wiki**: questa cartella, scritta solo dall'agente. Pagine per entità, concetti, sistemi e risultati.
- **Schema**: `CLAUDE.md` (struttura, convenzioni, flussi di lavoro).
- **index.md** (catalogo per contenuto) e **log.md** (cronologia, voci `## [data] tipo | titolo`, filtrabili con `grep "^## \[" wiki/log.md`).
- Operazioni: *ingest* dopo ogni modifica, *query* partendo dall'indice, *lint* periodico.
