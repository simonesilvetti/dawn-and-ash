---
title: Audio
type: system
tags: [audio, musica]
updated: 2026-10-20
sources: [scripts/autoload/Audio.gd, tools/fetch_assets.sh]
---

# Audio

- Bus: Master, Music, SFX, UI, con volumi nelle impostazioni; **M** silenzia la musica.
- Musica (OpenGameArt, CC0): menu *The Ancient Legend*, calma *Town Theme RPG*, combattimento *Battle Theme A*, jingle *Medieval Victory/Defeat*. **Crossfade** automatico verso il brano di combattimento quando Kael combatte, ritorno dopo 8 s di calma.
- Effetti (Kenney, CC0): 35 suoni (colpi, dardi, torri, esplosioni, scatto, onda d'urto, ossa degli scheletri, crolli, monete, interfaccia, livello, rinascita).
- Pool di 20 player 3D (attenuazione con la distanza) e 8 player 2D; pitch ±8%; massimo 3 suoni uguali contemporanei.
- Uscita ordinata (`Game.quit`): ferma e rilascia i flussi, niente risorse "ancora in uso".
> [!note] L'agente non può ascoltare: il test verifica che i file si carichino e i player partano (`Audio.started_count`, `failed_count`), il giudizio sull'ascolto spetta all'utente.
