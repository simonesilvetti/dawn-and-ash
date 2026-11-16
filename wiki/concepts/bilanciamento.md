---
title: Bilanciamento
type: concept
tags: [numeri, gameplay]
updated: 2026-11-16
sources: [scripts/autoload/Game.gd, scripts/debug/AutoTest.gd]
---

# Bilanciamento

**Tutti i numeri stanno in `scripts/autoload/Game.gd`**: è la fonte di verità. Le tabelle sono in [[kael]], [[peppino]], [[gorm]], [[abilita]], [[creep]], [[edifici]], [[oggetti]].
Ogni eroe ha le sue statistiche e abilità in `Game.HEROES` (`Game.hero_def(id)`, `Game.hero_abilities(id)`); il livello massimo è `Game.HERO_MAX_LEVEL` (10).

## Formule
- Armatura (stile Dota): `moltiplicatore = 1 − 0.06·A / (1 + 0.06·|A|)` → `Game.armor_multiplier`.
- Danno magico: `× (1 − resistenza)`; gli eroi hanno il 25%.
- XP per livello: `100 × livello`. Raggio XP 12 m; creep 40, torre 150, eroe 200 + 20 × livello (divisi tra gli eroi vicini).
- Rinascita: `4 + 2 × livello` secondi.
- Oro: iniziale 600, +1/s, last hit 35–45, torre 200 a squadra, uccisione eroe 250.

## Interruttori di fase
`ENABLE_SIEGE`, `ENABLE_ULTIMATE`, `ENABLE_DENY`, `ENABLE_CREEP_SCALING`, `ENABLE_PHASE2_ITEMS`, `ENABLE_MUSIC_CROSSFADE` (tutti attivi). → [[fasi-di-sviluppo]]

## Equilibrio tra gli eroi (duelli simulati)
`godot --headless -- --duel [--duel-runs N] [--duel-level L] [--duel-noitems] [--duel-ban <eroe><slot>] [--duel-stats]`
(`AutoTest._run_duel`) fa combattere i due eroi in simulazione pura, a metà corsia senza creep né torri, ai livelli
1, 3, 6 e 10 con gli stessi oggetti (nessuno; Spada; +Armatura e Gemma; +Stivali e Lama del vampiro). Lati alternati,
distanza iniziale e tempi di reazione casuali (0.12–0.3 s), così l'ordine di aggiornamento non decide il duello.
L'IA è semplice ma usa le abilità come un giocatore: Kael mira in anticipo, tiene la distanza da un nemico in mischia
e fugge con lo scatto; Peppino carica, alza lo scudo, usa fendente e spaccaterra. Gli scontri speculari
(Kael–Kael, Peppino–Peppino) servono da controllo (≈50%).

Taratura di Peppino (2026-10-22): con i primi valori vinceva 54 duelli su 60 al livello 10. Le prove con
`--duel-ban` e `--duel-noitems` hanno mostrato che pesava soprattutto la crescita per livello degli attacchi base;
sono state ridotte crescita di danno (4.5 → 3.7) e vita (90 → 82), armatura per livello (0.4 → 0.3), lo Scudo di ferro
(fino al 55% → fino al 44%) e lo stordimento della Carica. Corretta anche l'IA di Kael, che sbagliava 50 meteore su 60.
Risultato con 80 duelli per livello (vittorie Kael – Peppino): **40–40, 48–32, 40–40, 44–36** (Kael 54% in totale).

## Gorm (2026-11-16)
L'IA di Gorm (`AutoTest._duel_ai`) usa l'Eco del sisma entro 5.5 m, balza addosso col Totem tra 2.6 e 8 m, lancia la
Fenditura entro 11 m su un nemico non stordito e ricarica il totem sul posto da vicino. Opzioni nuove: `--duel-pair a,b`,
`--duel-ban` con più voci separate da virgola, `DUEL_TRACE=1` (stampa gli eventi di ogni duello).

Taratura: con i primi valori Gorm perdeva 39 su 40 contro Kael al livello 10 (l'Eco del sisma, senza creep attorno,
faceva solo il danno base) e dominava Peppino al livello 6 (55–5). Le prove hanno mostrato che:
- ogni abilità di Gorm da sola perde contro Peppino, ma **due qualsiasi** vincono: le stordite della Scossa di ritorno si
  concatenano; la traccia di un duello ha mostrato Peppino senza mana dopo l'apertura, mentre il Totem economico di
  Gorm continuava a dare colpi forti e stordimenti;
- contro Kael pesa la distanza: Gorm mette a segno la combinazione, poi Kael scatta via e lo finisce con la Meteora.

Interventi della prima taratura: Scossa e Fenditura con stordimenti più corti, Totem più caro e con +1 m di gittata,
eco anche su chi l'ha generata, più resistenza magica. Quelle misure però erano falsate dalla torre (sotto).

## Taratura dei tre eroi senza torri (2026-11-16)
**Errore dello strumento trovato**: i duelli si svolgevano a ~10 m dalla T1 della Lega, che sparava all'avversario di chi
giocava per la Lega e indietreggiava (in 5 duelli Kael–Gorm, 28 colpi della torre su Gorm). Il commento diceva
"lontano da torri", ma non era vero. Ora le torri nei duelli non sparano (`AutoTest._duel_once`). Senza la torre Kael
perdeva quasi sempre: la taratura di Peppino del 2026-10-22 contava sull'aiuto della torre.

**Misura nuova**: oltre alle vittorie si guarda lo **scarto medio di vita** a fine duello
((vittorie A × vita residua A − vittorie B × vita residua B) / duelli). Molti duelli finiscono con il vincitore
al 2–8% di vita: gli eroi sono quasi pari e ogni piccolo ritocco sposta *tutti* i duelli dalla stessa parte (per
esempio 0,05 s di stordimento della Scossa hanno portato Peppino–Gorm al livello 1 dall'80% al 19%). Lo scarto
dice quanto è netto un vantaggio; la sola percentuale di vittorie inganna.

Tracce dei duelli (`DUEL_TRACE=1`) che hanno guidato le scelte:
- Peppino contro Gorm restava senza mana dopo l'apertura, mentre il Totem di Gorm tornava ogni ~11 s: Fendente più
  economico, più mana per Peppino.
- Gorm usava tutto subito e Kael scappava con lo Scatto: l'IA di Gorm ora tiene il balzo se l'avversario può ancora
  scattare; Gorm più veloce (7.3) per inseguire.

Valori cambiati: **Kael** vita 600 (+80) → 660 (+88); **Peppino** mana 250 (+30) → 280 (+36), rigenerazione
1.3 (+0.12) → 1.45 (+0.15), vita per livello 82 → 78, Fendente 75 → 60 mana; **Gorm** vita 680 (+88) → 700 (+92),
danno per livello 4.3 → 4.6, velocità 7.0 → 7.3, resistenza magica 33% → 40%, Fenditura 100/150/200/250 →
110/155/200/245, Scossa 40–100 → 35–80 danni e 0.3–0.6 → 0.25–0.4 s, Eco del sisma 170/270/370 → 190/290/390.
(Palla di fuoco e Meteora erano state indebolite durante le prove e sono tornate ai valori di prima.)

Risultato, 120 duelli per caso (vittorie del primo eroe, tra parentesi lo scarto medio di vita):

| Livello | Kael – Peppino | Kael – Gorm | Peppino – Gorm |
|---|---|---|---|
| 1 | 37% (−3) | 15% (−5) | 80% (0) |
| 3 | 96% (+8) | 55% (+1) | 52% (0) |
| 6 | 1% (−4) | 68% (0) | 30% (−2) |
| 10 | 33% (−3) | 60% (+8) | 42% (−1) |

Vittorie complessive: Kael 46%, Peppino 54%, Gorm 48%. Gli scontri speculari (80 per livello) sono tra 39% e 61% con
scarti uguali per i due lati: lo strumento non favorisce più un lato. Strumento: `--duel-pair`, scarto calcolabile
dalla riga di riepilogo.

> [!warning] Le percentuali estreme della tabella (1%, 96%) corrispondono a scarti di 4–8 punti di vita: duelli
> quasi pari decisi sempre dalla stessa parte, non squilibri netti. Vanno confermate con partite vere.

> [!warning] L'IA dei duelli è semplice: misura l'ordine di grandezza dell'equilibrio, non sostituisce partite vere.
