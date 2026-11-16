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

Interventi: stordimento della Scossa 0.5–0.95 → 0.3–0.6 s e raggio 3.4 → 3.0; Fenditura 0.8–1.4 → 0.7–1.0 s;
Totem 50 → 55 mana, ricarica 11–8 → 12–9 s, bonus +100–250% → +80–260%, **+1 m di gittata** sul colpo potenziato;
**ogni eco colpisce anche chi l'ha generata** (un eroe da solo ne riceve due); resistenza magica 25% → 33% con armatura
più bassa (2.5 +0.35). Risultato con 80 duelli per livello:

| Livello | Kael – Gorm | Peppino – Gorm |
|---|---|---|
| 1 | 41–39 | 35–45 |
| 3 | 60–20 | 33–47 |
| 6 | 59–21 | 9–71 |
| 10 | 52–28 | 51–29 |

> [!warning] Squilibri ancora aperti: Gorm vince quasi sempre contro Peppino al livello 6 e perde circa 3 a 1 contro
> Kael ai livelli 3 e 6. I risultati cambiano a scatti (stessi semi, stessi scontri decisivi), quindi altre piccole
> correzioni non spostavano i numeri. Nei duelli mancano i creep, che in corsia rendono l'Eco del sisma molto più forte.

> [!warning] L'IA dei duelli è semplice: misura l'ordine di grandezza dell'equilibrio, non sostituisce partite vere.
