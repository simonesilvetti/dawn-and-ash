---
title: Stile grafico
type: concept
tags: [grafica, arte]
updated: 2026-10-21
sources: [promt.md, scripts/world/MapBuilder.gd, scripts/world/ground.gdshader, scripts/world/Scenery.gd]
---

# Stile grafico

**Stilizzato con texture** (dalla "Grafica v2", 2026-10-21): personaggi e edifici **KayKit** (cartoon, proporzioni
"chunky") su un terreno con **texture CC0 vere** (ambientCG), rilievo, acqua e molti dettagli. Riferimento di
dettaglio: Dota 2, senza pretendere di raggiungerlo. Visuale dall'alto inclinata di 50°.

> [!warning] `promt.md` chiedeva "low-poly cartoon, colori pieni con texture minime". Lo stile è stato cambiato su
> richiesta dell'utente (troppo minimale): vedi `DECISIONS.md` e [[piano-grafica-v2]].

- Modelli: **KayKit** (CC0) per personaggi, edifici, alberi, rocce e oggetti di scena → [[asset]].
- Terreno: texture di erba, sentiero, lastricato, roccia, ciottoli e terra bruciata con normal map, mescolate per zona
  (`ground.gdshader`); rilievo visivo con argini e colline (`Terrain.gd`). → [[mappa]]
- Fiume incassato con acqua trasparente, schiuma a riva e riflessi (`water.gdshader`); le unità guadano.
- Vegetazione minuta (erba, fiori, cespugli, canne, sassi) e basi fortificate con un villaggio attorno (`Scenery.gd`).
- Sassi KayKit con dettaglio di roccia proiettato, per legarli al terreno con texture.
- Luce calda di pomeriggio, tonemap Filmic, glow, nebbia leggera, falò e bracieri con luce tremolante.
- Effetti a strati (lampo, fuoco, fumo, scintille), code continue, bruciature a terra. → [[rendering-e-vfx]]
- Interfaccia ornata (pannelli a shader, icone dipinte, ritratto 3D). → [[interfaccia]]
