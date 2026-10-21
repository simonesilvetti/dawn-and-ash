# Decisioni prese in autonomia

Scelte fatte durante lo sviluppo senza chiedere all'utente, come richiesto da `promt.md`, con motivazione e limiti noti.
Riassunto nel wiki: `wiki/concepts/decisioni.md`.

## Ambiente
- **Godot 4.7.2.stable** installato dall'utente con `sudo pacman -S godot` (versione Arch, `4.7.2.stable.arch_linux`).
- **Template di esportazione**: l'archivio ufficiale pesa 1.3 GB. `tools/fetch_templates.py` scarica **solo**
  `linux_release.x86_64` e `version.txt` leggendo lo zip remoto con richieste HTTP Range (~28 MB). Installati in
  `~/.local/share/godot/export_templates/4.7.2.stable/`. Si esporta solo la build *release*; non serve quella di debug.
- `godot -s script.gd` non carica gli autoload: i test girano tramite la scena principale con argomenti dopo `--`.

## Asset
- **Modelli**: solo KayKit (CC0), come da prompt. Il **creep d'assedio** (Fase 2) usa il Barbaro (Lega) e lo
  Skeleton Minion ingrandito (Culto), che lanciano rocce con l'animazione `Throw`, invece di una catapulta (non c'è
  una catapulta animata coerente nello stile KayKit dei personaggi).
- **Musica**: 5 brani CC0 da OpenGameArt (non generata proceduralmente, dato che il download ha funzionato).
- **Effetti sonori**: pacchetti Kenney (CC0). Alcuni suoni "magici" vengono dal pacchetto sci-fi (laser, force field)
  perché è il più adatto tra quelli CC0 disponibili. Non ho potuto ascoltarli: va verificato a orecchio.
- **Icone** di abilità e oggetti e **ritratto** di Kael disegnati via codice (nessun asset esterno necessario).
- Font: quello predefinito di Godot.

## Gioco
- **Kael senza cappello**: dalla visuale dall'alto il grande cappello del Mage KayKit copriva tutto il personaggio
  (verificato con gli screenshot). Senza cappello si vedono testa, mantello colorato e bastone infuocato.
- **Punti abilità**: Q parte al livello 1 e c'è 1 punto da spendere all'inizio. Livello richiesto per il livello n di
  un'abilità base: `2n−1`; per la R: 6/8/10 (il livello massimo dell'eroe è 10).
- **Le abilità non danneggiano gli edifici** (come in Dota). **Resistenza magica 25%** per gli eroi.
- L'eroe da fermo **attacca da solo** i nemici entro la sua gittata (come in Dota); con A + click cerca bersagli entro 8 m.
- La **fontana** fa anche da negozio (entro 18 m). Negozio aperto anche da morto, se si è vicini.
- **Deny**: solo creep (non edifici), sotto il 50%; il nemico riceve metà XP.
- **Differenze minori rispetto al prompt**: niente frase vocale (solo testo a schermo, la voce era opzionale);
  niente rallentamento finale in rete (solo in allenamento). Il cursore (spada rossa sui nemici, mirino durante la
  mira) è disegnato via codice.

## Tecnica
- **Niente navmesh**: l'area percorribile è l'unione di forme convesse (capsula della corsia + cerchi delle basi), con
  movimento diretto + proiezione sul bordo e scivolamento attorno agli edifici. Non incastra mai le unità ed è
  molto più leggero (il prompt ammetteva questa alternativa).
- **AnimationPlayer con blend** invece di AnimationTree: per decine di creep è più semplice e leggero; il risultato
  visivo (transizioni morbide) è lo stesso.
- **Rete con snapshot binari propri** invece di `MultiplayerSynchronizer`/`MultiplayerSpawner`: serve controllo su
  delta compression, quantizzazione, intestazione per client con ack dei comandi. Gli spawn passano come eventi affidabili.
- **Snapshot a 30 Hz** (uno per tick) invece di 20 Hz: con la delta compression la banda resta ~8 KB/s, molto sotto i 30 KB/s.
- **Riconciliazione con ack**: ogni comando ha un numero di sequenza; il server comunica quale ha eseguito e in quale
  tick; il client allinea esattamente la predizione (vedi `wiki/systems/netcode.md`).
- **Eventi sul client applicati al tempo di rendering** (stesso ritardo dell'interpolazione), così animazioni,
  proiettili e posizioni sono coerenti.
- **Unità ferme non estrapolate**: con la delta compression un'unità che non cambia non viene inviata; il client la
  considera ferma (prima veniva estrapolata e poi "scattava" indietro di quasi 1 m).
- **Barre della vita e numeri** disegnati in un unico overlay 2D (`Overlay._draw`), non un nodo per unità.
- **Hit-stop** solo in allenamento (in rete il tempo non può fermarsi per uno solo dei giocatori).
- **Test in SubViewport 1600×900**: il window manager (Hyprland) affianca/ridimensiona la finestra di gioco, quindi
  screenshot e benchmark disegnano in un viewport a dimensione fissa.
- **Preset Media**: FXAA invece di MSAA, ombre solo per eroi ed edifici (i creep hanno un'ombra "blob" nell'anello),
  vegetazione al 70%. Ombre di creep e alberi, MSAA e SSAO solo in Alta.

## Prestazioni (limiti e note)
- Macchina di sviluppo: **Intel Iris Xe su Alder Lake-UP4 (chip da 9 W)**, spesso **a batteria**, con forte
  riduzione della frequenza per calore. È più debole del "PC medio" del prompt. Le misure variano fino al 30% tra prove identiche.
- Risultato finale in **Media**: ~90 FPS medi, 1% low ~65 nello scenario di carico (5 ondate per lato + abilità),
  tick di simulazione ~1 ms, ~530 draw call → limiti rispettati.
- **Alta** su questo chip: ~40 FPS (sotto i 60): è pensata per GPU dedicate. Il prompt chiedeva ≥ 120 FPS su hardware
  discreto: **non verificato**, perché non ho una GPU dedicata a disposizione.
- Nessun elemento della Fase 2 è stato scartato: dopo ognuno il benchmark e i test di rete restavano nei limiti.

## Elementi della Fase 2
Tutti implementati e attivi (interruttori `ENABLE_*` in `scripts/autoload/Game.gd`): Meteora, creep d'assedio,
rafforzamento dei creep ogni 5 minuti, deny, 4 oggetti extra e vendita, crossfade della musica, hit-stop, scossa della
telecamera, ombre delle nuvole, particelle ambientali, monete volanti, rallentamento finale, tabella punteggio,
opzioni di allenamento, menu con mappa in orbita.

## Grafica v2 (2026-10-21, su richiesta dell'utente)
L'utente ha giudicato la grafica "troppo minimale" e ha chiesto più dettaglio con Dota 2 come riferimento, mantenendo
la giocabilità, e un HUD migliore. Piano e dettagli: `wiki/concepts/piano-grafica-v2.md`.
- **Stile**: da "low-poly a colori pieni con texture minime" (prompt) a **"stilizzato con texture"**. I modelli restano
  KayKit; il terreno usa texture fotografiche CC0 di **ambientCG** (nuova fonte di asset, solo texture), tinte e
  saturate per stare vicino alla palette cartoon. Ai sassi KayKit si sovrappone il dettaglio della texture di roccia.
- **Rilievo solo visivo** (`Terrain.gd`): la simulazione resta sul piano, quindi rete, IA e test non cambiano.
  Le unità nel guado scendono di quota solo nella grafica.
- **Acqua**: un rettangolo piatto nascosto dal terreno più alto (la riva nasce dal test di profondità), invece di una
  mesh che segue il fiume.
- **Basi fortificate**: mura KayKit ad anello (MultiMesh) appena fuori dall'area percorribile, con varco verso la
  corsia; villaggio dietro le mura su terreno spianato. La pietra del Culto è scurita con una tinta (stesso atlante).
- **HUD**: pannelli disegnati da uno shader (`UiPanel`) invece di StyleBoxFlat; icone procedurali a shader; ritratto
  3D del vero modello (risolve il ritratto disegnato che non somigliava a Kael); negozio sopra il pannello.
- **Import delle texture**: compressione VRAM + mipmap obbligatorie (senza, il preset Media perdeva un terzo degli FPS).
- **Preset Media**: erba al 30%, ombre dei piccoli oggetti di scena disattivate, niente filtro anisotropico sul terreno.
