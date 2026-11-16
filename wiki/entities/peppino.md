---
title: Peppino, il Guerriero
type: entity
tags: [eroe, personaggio]
updated: 2026-11-16
sources: [scripts/autoload/Game.gd, scripts/sim/Sim.gd, scripts/world/UnitView.gd, scripts/vfx/Vfx.gd, scripts/debug/AutoTest.gd]
---

# Peppino, il Guerriero

Guerriero **corpo a corpo** con spada e scudo, secondo eroe dopo [[kael]]. Si sceglie nel menu principale (scheda "Eroe");
la scelta è salvata in `Game.settings.hero` e in rete arriva all'host con il saluto del client (vedi [[netcode]]).
Gioca per entrambe le fazioni, come Kael.

## Aspetto
- Modello KayKit **Knight** (`assets/models/chars/Knight.glb`), scala 0.98: lo stesso dei creep corpo a corpo della
  [[lega-dell-alba]], ma più grande, con **elmo dorato** (violaceo per il [[culto-della-cenere]]), mantello rosso/viola
  e **scudo a goccia** (`Badge_Shield`, i creep hanno quello tondo). Spada `1H_Sword`.
- Animazioni: Idle, Running_A, 1H_Melee_Attack_Slice_Diagonal (attacco); abilità: 2H_Melee_Attack_Spin (Q),
  1H_Melee_Attack_Stab (W), Block (E), 2H_Melee_Attack_Chop (R). Configurazione in `UnitView.MODELS["hero_peppino"]`.
- Ritratto dell'HUD con un'inquadratura più alta (l'elmo è più alto del mago).

## Statistiche (livello 1, +per livello) — fonte `Game.HEROES.peppino`
| Vita | Rig. vita | Mana | Rig. mana | Danno | Intervallo attacco | Gittata | Velocità | Armatura |
|---|---|---|---|---|---|---|---|---|
| 660 (+78) | 2.5 (+0.25) | 280 (+36) | 1.45 (+0.15) | 50 (+3.7) | 1.35 s (−0.035, min 0.75) | 1.6 (mischia) | 7.3 | 4 (+0.3) |

Resistenza magica 25%. Attacco in mischia (nessun proiettile): il danno arriva al "punto d'impatto" (0.35 s).

## Abilità — fonte `Game.HEROES.peppino.abilities`
| Tasto | Abilità | Bersaglio | Effetto | Mana | Ricarica |
|---|---|---|---|---|---|
| Q | Fendente rotante | attorno a sé | 85/140/195/250 danno magico in 3.2 m | 60 | 7 s |
| W | Carica | punto (9 m) | scatto a 34 m/s; all'arrivo 50/75/100/125 in 2.4 m + stordimento 0.7/0.85/1.0/1.15 s | 70 | 16/14/12/10 s |
| E | Scudo di ferro | sé | danni subiti −20/28/36/44% per 4 s | 80 | 15 s |
| R | Spaccaterra | direzione (12 m) | crepa in linea larga 2.2 m: 260/400/540 + stordimento 1.6 s | 180 | 60/50/40 s |

Regole comuni (livelli richiesti, mira, apprendimento) in [[abilita]].

## Simulazione
- La **Carica** non è un teletrasporto: l'unità scivola verso il punto (`Unit.dash_*`, `Sim._update_dash`), non può
  essere interrotta, e all'arrivo colpisce e prende come bersaglio il nemico colpito (un eroe ha la precedenza).
  Durante lo scatto lo stato è CASTING: sul client la predizione segue il server.
- Lo **Scudo di ferro** riduce ogni danno (fisico e magico) in `Sim._damage` (`Unit.shield_time/shield_pct`);
  il flag `F_SHIELDED` (128) lo trasmette ai client, che mostrano una bolla dorata (`UnitView._update_buff_shield`).
- La **Spaccaterra** colpisce subito tutti i nemici non edifici a distanza ≤ larghezza + raggio dal segmento.

## Effetti
Vortice d'aria tagliente e anelli d'acciaio (Q); polvere lungo il percorso e impatto con scintille (W); colonna e
bolla dorate (E); crepa incandescente che si apre verso la punta (`crack.gdshader`), rocce e polvere in sequenza (R).
Vedi [[rendering-e-vfx]].

## Equilibrio
Misurato con `godot --headless -- --duel` (IA semplice, stessi oggetti, lati alternati): vedi [[bilanciamento]].
I primi risultati (2026-10-22, Kael–Peppino 40–40, 48–32, 40–40, 44–36) erano falsati da una torre che sparava durante
i duelli. Dopo la taratura del 2026-11-16 (più mana, Fendente a 60, vita per livello 78) lo scarto medio di vita contro
Kael e contro [[gorm]] è entro ±8% a ogni livello. Peppino è forte all'inizio di uno scontro (carica + stordimento) e
resiste di più; Kael fa più danni a distanza e scappa con lo scatto.
