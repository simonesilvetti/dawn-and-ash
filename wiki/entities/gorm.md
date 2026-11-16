---
title: Gorm, lo Scuotiterra
type: entity
tags: [eroe, personaggio]
updated: 2026-11-16
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd, scripts/sim/MapData.gd, scripts/world/UnitView.gd, scripts/world/World.gd, scripts/vfx/Vfx.gd, scripts/debug/AutoTest.gd]
---

# Gorm, lo Scuotiterra

Gigante **corpo a corpo** con un totem di pietra, terzo eroe dopo [[kael]] e [[peppino]]. Ispirato all'Earthshaker di
Dota 2: è l'eroe che **stordisce**. Ogni abilità lanciata innesca la passiva *Scossa di ritorno*, che stordisce chi gli
sta vicino. Si sceglie nel menu (scheda "Gorm"); gioca per entrambe le fazioni.

## Aspetto
- Modello KayKit **Barbarian** (`assets/models/chars/Barbarian.glb`), scala 1.06, con il cappello d'orso. Lo stesso
  modello dei creep d'assedio della [[lega-dell-alba]] (scala 0.86, senza arma): Gorm si riconosce dal totem.
- **Totem** costruito con mesh primitive condivise (`UnitView._dress_shaker`), agganciato all'osso `handslot_r` al
  posto dell'ascia: manico di legno con legature di cuoio, testa ottagonale di pietra, punta più chiara e una **fascia di
  rune** emissiva (arancio per la Lega, viola per il Culto). Col Totem del sisma carico le rune si accendono e il totem
  emette braci e luce (`UnitView._set_empowered`).
- Animazioni (`UnitView.MODELS["hero_gorm"]`): fermo `2H_Melee_Idle`, corsa `Running_A`, attacco `2H_Melee_Attack_Slice`,
  Fenditura e Totem sul posto `2H_Melee_Attack_Chop` (il colpo a terra è al 57% della clip: velocità 1.86 e 3.0 perché
  coincida con il cast point), balzo `Jump_Full_Short` adattato alla durata, morte `Death_B`.
- **Balzo**: la posizione a terra arriva dalla simulazione; il modello segue un arco (`UnitView.leap`, altezza 1.9 m).
  Anche l'Eco del sisma ha un piccolo salto sul posto (1.3 m) che atterra quando l'abilità ha effetto.

## Statistiche (livello 1, +per livello) — fonte `Game.HEROES.gorm`
| Vita | Rig. vita | Mana | Rig. mana | Danno | Intervallo attacco | Gittata | Velocità | Armatura | Res. magica |
|---|---|---|---|---|---|---|---|---|---|
| 680 (+88) | 2.6 (+0.25) | 270 (+32) | 1.4 (+0.13) | 48 (+4.3) | 1.45 s (−0.04, min 0.8) | 1.7 (mischia) | 7.0 | 2.5 (+0.35) | 33% |

Più resistenza magica e meno armatura degli altri eroi (gigante di terra): è la leva usata per l'equilibrio con Kael
(danni tutti magici) senza rafforzarlo contro Peppino (danni soprattutto fisici). Vedi [[bilanciamento]].

## Abilità — fonte `Game.HEROES.gorm.abilities`
| Tasto | Abilità | Bersaglio | Effetto | Mana | Ricarica |
|---|---|---|---|---|---|
| Q | Fenditura | direzione (12 m) | 100/150/200/250 in linea larga 1.2 m + stordimento 0.7/0.8/0.9/1.0 s; **muro di roccia** per 5 s | 110/120/130/140 | 18/17/16/15 s |
| W | Totem del sisma | punto (7 m) | balzo in 0.45 s (sul posto se il punto è entro 1 m); il prossimo attacco entro 12 s fa +80/140/200/260% di danno e arriva 1 m più lontano | 55 | 12/11/10/9 s |
| E | Scossa di ritorno | **passiva** | a ogni abilità lanciata: 40/60/80/100 e stordimento 0.3/0.4/0.5/0.6 s entro 3 m | — | — |
| R | Eco del sisma | attorno a sé (7 m) | 170/270/370 a tutti i nemici; dopo 0.35 s ogni colpito riceve 35/48/60 per ogni eco (un'eco per nemico colpito, due per gli eroi, sé stesso compreso, massimo 10) | 200/220/240 | 75/65/55 s |

La Scossa scatta dopo la Fenditura, all'**atterraggio** del Totem (o subito, se sul posto) e dopo l'Eco del sisma.
La passiva non si lancia: premere E mostra "abilità passiva" (`World.try_ability`), il server la rifiuta (`Sim._try_cast`).

## Simulazione
- **Muri** (`Sim.walls`, voci `{a, b, w, until}`): segmento dalla punta dei piedi di Gorm fino alla gittata, riportato
  dentro l'area percorribile; semilarghezza 0.75 m. Chi si trova sulla linea viene spinto dal proprio lato
  (`MapData.push_from_wall`). Durano 5 s.
- **Blocco e aggiramento**: `_move_towards` spinge fuori dai muri; se il tragitto diretto attraversa un muro,
  `MapData.wall_detour` dà come tappa l'**angolo oltre l'estremità più conveniente, dal lato della meta**. Da lì la linea
  verso la meta è libera; per arrivarci l'unità scivola lungo il fianco e gira attorno alla punta. Due versioni
  precedenti si incastravano (vedi [[log]] del 2026-11-16). Una meta dentro il muro si considera raggiunta a contatto.
- La **Carica** di Peppino si ferma contro un muro; il **balzo** di Gorm ci passa sopra (ma non atterra dentro).
- **Totem**: `Unit.empower_time/mult/range`; il colpo potenziato è in `_attack_hit` (evento `fx totem_hit`).
  Flag `F_EMPOWERED` (256) negli snapshot (flag ora a 16 bit, vedi [[netcode]]).
- **Eco del sisma**: danno immediato, poi un effetto ritardato `type: "echo"` in `Sim.delayed` (generalizzato dalla
  Meteora) con i danni per ogni bersaglio. Un eroe da solo riceve comunque le sue due echi.

## Effetti (`Vfx.gd`)
- **Fenditura** (`Vfx.fissure`): crepa incandescente che si apre verso la punta, solco scuro, polvere e detriti a ondata;
  **13 rocce** (mesh e materiale condivisi, istanza dal pool) emergono in sequenza con un rimbalzo elastico e un
  tremolio, poi negli ultimi 0.45 s sprofondano nella polvere. I sassi KayKit sono piccoli (~0.3 m): la scala si calcola
  dalla misura vera di ogni mesh. Ombre delle rocce solo in qualità Alta.
- **Totem**: anello di terra al decollo; all'atterraggio anello, colonna di luce delle rune e polvere; colpo potenziato
  con anello, colonna, scintille e luce.
- **Scossa di ritorno**: muro basso color terra e anello che si allargano fino a 3.5 m, piccoli detriti (+0.06 s dopo il colpo).
- **Eco del sisma** (`Vfx.echo_slam`): onda sismica (cilindro con lo shader del fuoco color terra) che si allarga a 7 m,
  doppio anello, grande nuvola di polvere, detriti, luce e scossa forte della telecamera; ogni nemico colpito "risuona"
  quando l'onda lo raggiunge e di nuovo all'arrivo dell'eco (`echo_hit`).
- Stordimento visibile per tutti gli eroi e i creep: stelline che girano sopra la testa (`UnitView._update_stun_fx`).
- Suoni: `collapse` + `big_explosion` (Fenditura), `shockwave` (totem), `hit_punch_*` (scossa, echi), `explosion_1`
  (colpo potenziato). Hit-stop in allenamento sulla Fenditura, sul colpo potenziato e sull'Eco.

## Icone
Disegnate in `scripts/ui/icon.gdshader`: 8 Fenditura (crepa tra due file di punte di roccia), 9 Totem (totem con le
rune che pulsano), 19 Scossa (anelli di terra e stelline), 20 Eco (onde da più punti). Id in `IconRect.IDS`.

## Equilibrio
Duelli simulati, 80 per caso (vittorie del primo – di Gorm): vedi [[bilanciamento]]. Gorm è forte a metà partita contro
un altro corpo a corpo e soffre un mago che lo tiene a distanza; nei duelli l'Eco del sisma rende meno che in corsia,
dove i creep moltiplicano gli echi.
