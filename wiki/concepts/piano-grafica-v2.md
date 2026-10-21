---
title: Piano "Grafica v2" (più dettaglio, stesse prestazioni)
type: concept
tags: [grafica, piano, ui, prestazioni]
updated: 2026-10-21
sources: [promt.md, scripts/world/MapBuilder.gd, scripts/world/ground.gdshader, scripts/vfx/Vfx.gd, scripts/ui/Hud.gd]
---

# Piano "Grafica v2"

Richiesta dell'utente (2026-10-21): la grafica è troppo minimale. **Riferimento: Dota 2**, senza pretendere di
raggiungerlo, ma con molto più dettaglio **mantenendo la giocabilità** (preset Media ≥ 60 FPS medi e 1% low ≥ 45
sulla Iris Xe, vedi [[benchmark]]). Anche la "console dei comandi" (pannello HUD in basso) va migliorata.

Cambio di stile rispetto a `promt.md`: da "low-poly a colori pieni" a **"stilizzato con texture"**: modelli KayKit
invariati, ma terreno con texture CC0 vere (ambientCG), rilievo, acqua, molti più oggetti di scena, effetti più ricchi.
Annotato in `DECISIONS.md`. Vedi [[stile-grafico]].

## Cosa fa sembrare "ricco" Dota 2 e cosa possiamo fare

| Elemento | Dota 2 | Prima (v1) | v2 |
|---|---|---|---|
| Terreno | texture dipinte, sentieri consumati, rilievo e scogliere | colori piatti su un piano | texture CC0 (erba, terra, lastricato, roccia, ciottoli) con normal map, rilievo procedurale fuori dalla corsia, roccia sui pendii |
| Acqua | fiume incassato, rive, schiuma | chiazze ciano sul piano | alveo scavato, guado basso nella corsia, acqua trasparente con profondità, schiuma a riva, riflessi |
| Vegetazione | erba, cespugli, fiori, sassi ovunque | alberi e rocce sparsi | ciuffi d'erba, fiori, cespugli, sassolini (MultiMesh a blocchi, con culling) |
| Basi | villaggi fortificati | edifici isolati | mura con porta verso la corsia, fabbro, chiesa, mulino, mercato; base del Culto più scura con braci |
| Corsia | rovine, staccionate, falò | vuota | rovine, staccionate rotte, carri, falò con luce, ponte in rovina sul fiume |
| Luce | ombre morbide, AO, nebbia d'altezza | sole + nebbia | nebbia d'altezza (valli), AO "finta" nel terreno, SSAO solo in Alta, luci dei falò |
| Effetti | ricchi, a strati | pallini e anelli | palla di fuoco con nucleo animato e coda continua, esplosioni a strati (lampo, fuoco, fumo, scintille), bruciature a terra (Decal), scintille sui colpi |
| HUD | compatto, ornato, ritratto 3D | grande, mezzo vuoto, ritratto disegnato diverso dall'eroe | pannelli ornati a shader, ritratto 3D del vero modello, icone a shader, pannello compatto, negozio a schede |

## Fasi (ognuna: import, autotest, screenshot, benchmark, commit)

1. **Terreno e acqua** — `scripts/world/Terrain.gd` (altezza visiva + mesh), `ground.gdshader` v2 con texture, `water.gdshader`; le unità "guadano" il fiume (solo visivo).
2. **Ambiente** — vegetazione minuta a blocchi, basi fortificate, oggetti di scena della corsia, falò, braci del Culto, nebbia d'altezza.
3. **Effetti** — proiettili, esplosioni, Decal di bruciatura, onda d'urto, scatto, meteora, scintille dei colpi; scudo e cristalli degli edifici meno invadenti.
4. **HUD ("console dei comandi")** — pannelli a shader, layout compatto, ritratto 3D, icone a shader, abilità non imparate leggibili, statistiche con icone, negozio a schede senza sovrapposizioni, minimappa con il terreno vero.
5. **Verifica** — due cicli di revisione con screenshot, benchmark dei tre preset, wiki e `DECISIONS.md`.

## Budget di prestazioni (preset)

| | Bassa | Media | Alta |
|---|---|---|---|
| Texture terreno | solo colore | colore + normal | colore + normal + anti-ripetizione |
| Erba/fiori/sassi | no | 30% | 100% + ombre |
| Acqua | opaca | trasparente con profondità | + riflessi del cielo più ricchi |
| Luci dei falò | no | sì (poche) | sì |
| Decal di bruciatura | no | sì | sì |

Limiti da rispettare in Media: FPS medio ≥ 60, 1% low ≥ 45, draw call < 1000.

## Stato (2026-10-21 pomeriggio)

Fatto: fasi 1–4 (terreno, acqua, ambiente, effetti, HUD) e documentazione. Autotest OK, test di rete 5/5 OK,
screenshot aggiornati in `screenshots/`.

> [!warning] **Prestazioni non ancora nei limiti in Media.** Confronto a parità di calore: versione precedente
> 66–72 FPS (GPU ~12 ms), Grafica v2 ~48–56 FPS (GPU ~16–19 ms). Costi misurati (GPU, Media): erba ~3 ms (poi
> dimezzati i triangoli e ridotta la densità: da rimisurare), normal map del terreno ~1.7 ms, acqua ~1.4 ms,
> rilievo del terreno ~0.9 ms. Le misure variano molto col calore del chip da 9 W.

### Aggiornamento 2026-10-21 (sera): prestazioni recuperate
Misure stabili a macchina libera (Media, 20 s, alternate con `0e73d5e`). Costi GPU trovati con interruttori temporanei:
alberi/montagne ~4 ms (una MultiMesh per tipo su tutta la mappa: niente culling), acqua ~2 ms (copia del depth buffer),
rilievo ~1.8 ms (mesh unica), FXAA ~1 ms (c'era già prima), erba/normal map/scenografia ~0.6 ms ciascuno, luci dei falò ~0.
Correzioni: terreno e vegetazione a blocchi, acqua con mappa del fondo. Risultato: GPU 21.2 → ~15–16 ms, FPS 43 → 50–56,
alla pari con la versione precedente (54–55 nella stessa sessione). Erba, normal map e scenografia restano in Media.

> [!warning] Oggi la macchina è più lenta che nelle misure del 2026-10-20: anche la versione precedente fa ~55 FPS in
> Media invece di 87. I limiti assoluti (≥ 60 / 45) vanno ricontrollati con `--benchmark` sui tre preset.

### Aggiornamento 2026-10-21 (notte): verifica e rifinitura
A macchina fresca la v2 misura **Bassa 135/68, Media 87/63, Alta 46/41** (FPS medio / 1% low): limiti di Media
rispettati, sopra la versione finale precedente. Con il margine sono stati aggiunti, misurando a ogni passo:
acqua con scie della corrente, scintillii e schiuma a due fasce; increspature attorno alle unità nel guado; alberi con
tinta variabile; **occlusione finta** sotto boschi, rocce ed edifici (fa anche da ombra degli alberi in Media); sentiero
senza righe di ripetizione e con tracce consumate, orlo scuro tra erba e sentiero; piazze delle basi con terra battuta
e muschio; crepe di brace nella terra bruciata del Culto; cristalli a gemma; muro di fiamme dell'onda d'urto rifatto;
esplosioni grandi che non saturano al bianco; luce con ombre un po' più profonde. Dettagli in [[rendering-e-vfx]].
Risultato finale: **Bassa 133/73, Media 83/64, Alta 44/35**. Costo GPU in Media ~+0.5 ms; A/B nella base alla pari
entro il rumore. Vedi [[benchmark]].

### Prossimi passi
1. ~~Confronto A/B~~, ~~benchmark dei tre preset~~, ~~secondo ciclo di revisione (acqua del guado, luce)~~: fatti.
2. Possibili: Alta resta sui 45 FPS su questa GPU (pensata per GPU dedicate); fiamme delle esplosioni enormi
   (distruzione dell'Antico) ancora molto chiare quando tre si sovrappongono.

> [!note] Tentativo del 2026-10-21 (pomeriggio): misure inutilizzabili. Anche la versione precedente faceva ~47 FPS
> in Media (contro 87 del giorno prima) e la stessa configurazione oscillava tra 40 e 50 FPS. Rapporto indicativo
> v2/precedente ≈ 39/47 (−18%). Le finestre del benchmark disturbano l'utente: **misurare solo quando la macchina è
> libera e scarica** (fresca, nessun altro carico), oppure in uno special workspace di Hyprland dopo aver verificato
> che una finestra nascosta non venga rallentata.

Metodo A/B consigliato: `git worktree add <scratch>/old 0e73d5e`, `godot --headless --import` nella copia, poi
benchmark alternati tra le due cartelle (niente `git stash`). Ogni benchmark aggiunge righe a `benchmark_results.md`:
annullarle se sono solo prove.

Script A/B usato in precedenza (preset Media, alterna `git stash` / `git stash pop`; controllare `git stash list` se interrotto):
`godot -- --benchmark --bench-preset 1 --bench-seconds 12` sul commit `0e73d5e` (versione prima della v2) e su quella attuale, alternati, due volte ciascuno.
