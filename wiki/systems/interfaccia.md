---
title: Interfaccia utente
type: system
tags: [ui, hud]
updated: 2026-10-21
sources: [scripts/ui/, scripts/ui/Hud.gd, scripts/ui/UiPanel.gd, scripts/ui/ui_panel.gdshader, scripts/ui/icon.gdshader, scripts/ui/IconRect.gd, scripts/ui/AbilityButton.gd, scripts/ui/Minimap.gd]
---

# Interfaccia utente

Tema comune (`UiKit`): pannelli scuri semitrasparenti con bordi dorati, angoli arrotondati.
In partita i pannelli sono **`UiPanel`** (dalla v2): fondo con grana e vignettatura, doppia cornice dorata con riflesso e ornamenti, disegnati da `ui_panel.gdshader`.

- **Menu principale**: titolo, nome del giocatore, Allenamento, Ospita (porta, IP locali, lobby, Pronto), Unisciti (IP, porta, ultimo IP salvato), Impostazioni (qualità, FPS, schermo intero, VSync, lancio rapido, scorrimento, volumi), Esci. Sfondo: la mappa 3D in orbita.
- **HUD ("console dei comandi")**, compatto (744×146 px): **ritratto 3D** del vero modello dell'eroe (UnitView in un SubViewport a 30 Hz, con distintivo del livello), barra XP, vita e mana con gradiente, 4 abilità con **icone a shader** (`icon.gdshader`; spente ma riconoscibili se non imparate), ricarica a spicchio, tasto e costo in mana in riquadri leggibili, tacche del livello a rombo, "+" pulsante per imparare, lampo quando tornano pronte; 6 oggetti con icone; oro con pulsante "Negozio (B)" e statistiche con icone; punti abilità da spendere; orologio, punteggio, prossima ondata; ping/FPS; minimappa (10 Hz) con lo sfondo dipinto dal terreno vero (rilievo ombreggiato, boschi, mura, fiume); notifiche; tooltip; **negozio** a schede raggruppate (Consumabili, Attributi, Armi) con icona, prezzo rosso se l'oro non basta, sopra il pannello senza sovrapporsi; pausa con opzioni di allenamento; tabella punteggio (Tab); schermata di rinascita; conto alla rovescia; monete che volano verso l'oro.
- **Overlay** (`Overlay.gd`): tutte le barre della vita (con scia ritardata e tacche ogni 250) e i numeri fluttuanti in un'unica `_draw()`.
- **Cursore** disegnato via codice: spada rossa sui nemici, mirino arancio durante la mira delle abilità (`Hud._make_cursor`).
- **Fine partita**: VITTORIA/SCONFITTA con statistiche, Rigioca (allenamento) e Menu principale.
