---
title: Interfaccia utente
type: system
tags: [ui, hud]
updated: 2026-10-20
sources: [scripts/ui/]
---

# Interfaccia utente

Tema comune (`UiKit`): pannelli scuri semitrasparenti con bordi dorati, angoli arrotondati.

- **Menu principale**: titolo, nome del giocatore, Allenamento, Ospita (porta, IP locali, lobby, Pronto), Unisciti (IP, porta, ultimo IP salvato), Impostazioni (qualità, FPS, schermo intero, VSync, lancio rapido, scorrimento, volumi), Esci. Sfondo: la mappa 3D in orbita.
- **HUD**: ritratto di Kael disegnato, barra XP, vita e mana, 4 abilità con ricarica a spicchio (ritagliato nell'icona), costo, livelli, "+" per imparare, lampo quando tornano pronte; 6 oggetti; oro; statistiche; orologio, punteggio, prossima ondata; ping/FPS; minimappa (10 Hz); notifiche; tooltip; negozio; pausa con opzioni di allenamento; tabella punteggio (Tab); schermata di rinascita; conto alla rovescia; monete che volano verso l'oro.
- **Overlay** (`Overlay.gd`): tutte le barre della vita (con scia ritardata e tacche ogni 250) e i numeri fluttuanti in un'unica `_draw()`.
- **Cursore** disegnato via codice: spada rossa sui nemici, mirino arancio durante la mira delle abilità (`Hud._make_cursor`).
- **Fine partita**: VITTORIA/SCONFITTA con statistiche, Rigioca (allenamento) e Menu principale.
