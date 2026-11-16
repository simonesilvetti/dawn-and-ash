---
title: Interfaccia utente
type: system
tags: [ui, hud]
updated: 2026-11-16
sources: [scripts/ui/, scripts/ui/Hud.gd, scripts/ui/UiPanel.gd, scripts/ui/ui_panel.gdshader, scripts/ui/icon.gdshader, scripts/ui/IconRect.gd, scripts/ui/AbilityButton.gd, scripts/ui/Minimap.gd, scripts/ui/console.gdshader, scripts/ui/slot.gdshader, scripts/ui/bar.gdshader, scripts/ui/Cursors.gd]
---

# Interfaccia utente

Tema comune (`UiKit`): pannelli scuri semitrasparenti con bordi dorati, angoli arrotondati.
In partita i pannelli sono **`UiPanel`** (dalla v2): fondo con grana e vignettatura, doppia cornice dorata con riflesso e ornamenti, disegnati da `ui_panel.gdshader`.

- **Menu principale**: titolo, nome del giocatore, **scelta dell'eroe** (schede Kael / Peppino / Gorm con descrizione, salvata in `settings.hero`), Allenamento, Ospita (porta, IP locali, lobby, Pronto), Unisciti (IP, porta, ultimo IP salvato), Impostazioni (qualità, FPS, schermo intero, VSync, lancio rapido, scorrimento, volumi), **Informazioni** (titolo, versione, identificativo `Game.APP_ID`, autore `Game.AUTHOR`, sito `Game.WEBSITE` cliccabile, crediti degli asset), Esci. Sfondo: la mappa 3D in orbita.
- **HUD ("console dei comandi")**, compatto (744×146 px): **ritratto 3D** del vero modello dell'eroe (UnitView in un SubViewport a 30 Hz, con distintivo del livello), barra XP, vita e mana con gradiente, 4 abilità con **icone a shader** (`icon.gdshader`; spente ma riconoscibili se non imparate), ricarica a spicchio, tasto e costo in mana in riquadri leggibili, tacche del livello a rombo, "+" pulsante per imparare, lampo quando tornano pronte; 6 oggetti con icone; oro con pulsante "Negozio (B)" e statistiche con icone; punti abilità da spendere; orologio, punteggio, prossima ondata; ping/FPS; minimappa (10 Hz) con lo sfondo dipinto dal terreno vero (rilievo ombreggiato, boschi, mura, fiume); notifiche; tooltip; **negozio** a schede raggruppate (Consumabili, Attributi, Armi) con icona, prezzo rosso se l'oro non basta, sopra il pannello senza sovrapporsi; pausa con opzioni di allenamento; tabella punteggio (Tab); schermata di rinascita; conto alla rovescia; monete che volano verso l'oro.
- **Overlay** (`Overlay.gd`): tutte le barre della vita (con scia ritardata e tacche ogni 250) e i numeri fluttuanti in un'unica `_draw()`.
- **Cursori** (`Cursors.gd`, dal 2026-10-22): forme a distanza con segno calcolate a 4× e ridotte con filtro Lanczos, creati una volta alla costruzione dell'HUD (~130 ms, non al primo passaggio del mouse). Spada d'acciaio con elsa dorata, impugnatura in cuoio, pomo con gemma, contorno scuro, alone rosso e ombra sui nemici (punta in alto a sinistra); mirino dorato ad anello con tacche durante la mira. Sostituiscono la spada a pixel 32×32 ("troppo retrò").
- **Fine partita**: VITTORIA/SCONFITTA con statistiche, Rigioca (allenamento) e Menu principale.

## Console (dal 2026-10-22)
Stessi elementi e posizioni, più dettaglio con Dota 2 come riferimento:
- **Pannello** (`console.gdshader` sul `UiPanel` in basso): fondo di bronzo scuro con grana e incisioni a rombi,
  cornice metallica smussata (luce dall'alto) con rivetti, scanalatura e filetto dorato, angoli ispessiti con una gemma
  del colore della squadra, **separatori incisi** con un rombo tra ritratto, abilità, oggetti e statistiche (posizioni
  calcolate dopo l'impaginazione, `Hud._update_console_deco`), **stemma** con gemma pulsante sopra le abilità.
- **Alloggiamenti** di abilità e oggetti (`slot.gdshader`, un `ColorRect` tra icona e testi in `AbilityButton`):
  incasso con ombra, cornice di metallo smussata (acciaio spento se non imparata), scanalatura, ombra interna
  sull'icona, ricarica a spicchio con **bordo luminoso**, velo blu senza mana, riflesso vetroso, lampo che attraversa
  l'icona quando torna pronta, bagliore al passaggio del mouse e quando si può imparare. Caselle vuote incassate con il
  numero inciso.
- **Testi** (`AbilityButton._Over`): targhetta del tasto con filo dorato, costo in mana su una gemma blu (rosso se
  manca il mana), ricarica con decimi sotto 1 s, **tacche del livello a barrette** smussate.
- **Barre** di vita e mana: velo vetroso (`bar.gdshader`) con riflesso, luccichio che scorre, filo luminoso sulla punta e
  **scia del danno** (la vita appena persa resta chiara 0.45 s, poi si ritira).
- **Ritratto**: cornice smussata con borchie, distintivo del livello ad anello dorato; inquadratura per eroe.
- Costo misurato: ~0.17 ms di GPU in Media (A/B, vedi [[benchmark]]).

## Gorm e abilità passive (2026-11-16)
- Ritratto di [[gorm]] con un'inquadratura più alta e lontana (cappello d'orso e totem).
- Abilità passive: nessun costo né ricarica nel tooltip, etichetta "(passiva)"; premere il tasto mostra un avviso.
  Tooltip con le voci nuove: eco per nemico, danno dell'attacco potenziato, durata del muro di roccia.
- Anteprima di mira in linea per le abilità `dir` con `width` (vedi [[rendering-e-vfx]]).
