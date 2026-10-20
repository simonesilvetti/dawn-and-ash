# Prompt: MOBA minimale in stile Dota 2 con Godot 4 (Linux)

> Questo prompt va eseguito **interamente in autonomia, in una sola sessione, senza fare domande all'utente**.
> Ogni volta che una scelta non è specificata, prendi la decisione più ragionevole, annotala in `DECISIONS.md` e prosegui.
> Non fermarti finché tutti i "Criteri di completamento" (sezione 12) non sono soddisfatti e verificati.

---

## 0. Contesto

- Macchina: Linux (Arch / Omarchy, Hyprland, Wayland), shell bash, utente non-root.
- Cartella di lavoro: `/home/simone/Work/game` (questo file è `promt.md` al suo interno).
- Obiettivo: un gioco **MOBA minimale in 3D low-poly**, stile Dota 2, realizzato con **Godot 4 (ultima stable 4.x)** e **GDScript**.
- Modalità di gioco:
  1. **Allenamento (single player)** — *priorità massima, deve funzionare perfettamente*: un solo eroe (il giocatore) contro le ondate di creep e le torri nemiche, con creep alleati. Si vince distruggendo l'Antico (base) nemico.
  2. **1 contro 1 in rete (LAN / internet)** — un giocatore fa da **host** sulla propria macchina (server + giocatore), l'altro si collega come **client** inserendo IP e porta.
- La grafica deve essere **curata e piacevole**: luci, ombre, particellari, feedback visivi. Non deve sembrare un prototipo grigio.
- I personaggi devono avere **animazioni vere** (camminata, attacco, lancio incantesimi, morte) e il gioco deve avere **musica** ed **effetti sonori** completi (sezioni 3.4 e 3.5).

---

## 0.1 Ambientazione, fazioni ed eroe

- **Titolo del gioco**: **"Ancients Clash"**, sottotitolo *"Le Terre di Aethra"*.
- **Mondo**: le *Terre di Aethra*, dove due antichi cristalli (gli **Antichi**) alimentano due regni rivali. Chi distrugge il cristallo nemico vince la guerra.
- **Radiant — la Lega dell'Alba**: cavalieri e maghi delle foreste dorate. Colori: verde‑azzurro con dettagli dorati. Creep: cavalieri/soldati (corpo a corpo) e maghi/arcieri (a distanza). Basi in pietra chiara con stendardi verde‑oro, vegetazione rigogliosa.
- **Dire — il Culto della Cenere**: scheletri e creature nate dalle rovine bruciate. Colori: rosso‑viola con dettagli neri/ossei. Creep: guerrieri scheletro (corpo a corpo) e maghi scheletro (a distanza); creep d'assedio (Fase 2) = golem/catapulta. Basi in pietra scura con braci, vegetazione secca e bruciata nella loro metà della mappa (transizione graduale dal verde al bruno/cenere oltre il fiume).
- **Eroe: Kael, il Piromante** — giovane mago della Lega dell'Alba che ha imparato a domare il fuoco dei cristalli. Aspetto: mago low-poly con mantello rosso (accenti nel colore della squadra), cappuccio o cappello, **bastone con cristallo infuocato** che emette una piccola luce e particelle di brace. Tema delle abilità: **fuoco + magia arcana** (effetti arancioni/oro e azzurri).
  - In 1 contro 1 entrambi i giocatori usano Kael; quello Dire ha mantello e accenti rosso‑viola scuro e fiamma del bastone violacea, così i due sono distinguibili a colpo d'occhio.
  - Frase d'ingresso a inizio partita e alla rinascita (testo a schermo/fumetto; voce opzionale): es. *"Il fuoco di Aethra arde in me!"*, *"Torno dalle ceneri."*
- Usa questi nomi in tutto il gioco: menu, HUD (ritratto "Kael — Livello 3"), tooltip, notifiche ("La Lega dell'Alba ha distrutto una torre del Culto della Cenere!"), schermata di vittoria/sconfitta, README. Nel codice gli identificatori interni restano `RADIANT`/`DIRE`.

---

## 0.2 Principio guida: prima semplice, fluido e stabile — poi bello

**Prestazioni, stabilità e assenza di lag hanno la precedenza su qualsiasi funzionalità o effetto grafico.** Meglio un gioco più piccolo che gira liscio a 60+ FPS e non si blocca mai, che uno ricco ma che scatta o crasha. Si lavora in fasi; **non si passa alla fase successiva finché la precedente non è stabile e performante** (test della sezione 11 superati).

**Fase 1 — Nucleo (obbligatoria, da rendere solidissima):**
- Mappa a una corsia, 2 torri + Antico + fontana per squadra.
- Eroe con movimento, attacco base, **Q, W, E** (la R è in Fase 2).
- Creep corpo a corpo e a distanza (niente creep d'assedio in Fase 1), ondate, IA semplice.
- Oro, XP, livelli; negozio con **5 oggetti** (Spada lunga, Armatura di cuoio, Stivali, Gemma della vitalità, Pozione di cura).
- HUD essenziale (vita, mana, abilità con ricarica, oro, livello, orologio, minimappa semplice), menu principale, fine partita.
- Grafica: luci, ombre, terreno, modelli animati (idle/walk/attack/death), barre vita, numeri del danno, particellari per le abilità — **con impostazioni di qualità**.
- Audio: musica menu + partita, effetti sonori base.
- Modalità Allenamento + 1v1 in rete con netcode robusto (sezione 10.4).

**Fase 2 — Arricchimento (solo se la Fase 1 è stabile e il budget di prestazioni lo consente):**
- Abilità R (Meteora), creep d'assedio, rafforzamento dei creep nel tempo, deny.
- Oggetti restanti (Cristallo arcano, Anello di rigenerazione, Pozione di mana, Lama del vampiro), vendita oggetti.
- Crossfade musica combattimento/calma, hit-stop, scossa telecamera, nuvole d'ombra, lucciole, monete che volano, rallentamento finale.
- Tabella punteggio (Tab), opzioni di allenamento extra, menu con mappa che orbita.

Ogni elemento di Fase 2 si aggiunge **uno alla volta**, rieseguendo dopo ciascuno i test di prestazioni e rete; se peggiora FPS, banda o stabilità oltre i limiti delle sezioni 10.4, 10.5 e 11 (punto 4), si semplifica o si scarta (annotandolo in `DECISIONS.md`). Le sezioni seguenti descrivono il gioco completo: ciò che appartiene alla Fase 2 va fatto solo alle condizioni appena descritte.

---

## 1. Setup dell'ambiente (in autonomia)

1. Verifica se Godot 4 è già disponibile: `godot --version` / `godot4 --version`.
2. Se non c'è, prova in quest'ordine:
   1. `sudo -n pacman -S --noconfirm godot` (funziona solo se sudo non chiede password; **non** restare bloccato in attesa di una password).
   2. Altrimenti scarica il binario ufficiale dall'ultima release stable 4.x su GitHub (`godotengine/godot`, asset `Godot_v4.x-stable_linux.x86_64.zip`), usando l'API `https://api.github.com/repos/godotengine/godot/releases/latest` per trovare l'URL esatto. Estrailo in `./tools/godot/` e crea uno script `./godot.sh` che lo lanci. Scarica anche gli **export templates** della stessa versione (`Godot_v4.x-stable_export_templates.tpz`) e installali in `~/.local/share/godot/export_templates/<versione>/` (es. `4.5.stable`).
3. Annota in `DECISIONS.md` quale versione è stata installata e come.
4. Da qui in avanti, chiama Godot sempre tramite una variabile/percorso unico (es. `GODOT=./godot.sh` oppure `godot`).

---

## 2. Struttura del progetto

Crea il progetto Godot direttamente in `/home/simone/Work/game/` (il `project.godot` sta nella radice). Struttura indicativa:

```
project.godot
icon.svg
README.md
DECISIONS.md
export_presets.cfg
run.sh                 # avvia il gioco
build.sh               # esporta l'eseguibile Linux in build/
scripts/
  autoload/
    Game.gd            # stato globale: modalità, team del giocatore, costanti di bilanciamento
    Net.gd             # host/join/disconnessione, ENet, segnali di rete
    Audio.gd           # musica (crossfade tra brani) + effetti sonori con pool di player, bus audio
  units/
    Unit.gd            # classe base: vita, mana, team, armatura, morte, barra vita
    Hero.gd
    Creep.gd
    Tower.gd
    Ancient.gd
  abilities/
    Ability.gd         # classe base: costo mana, ricarica, gittata, tipo di bersaglio
    Fireball.gd        # Q
    Blink.gd           # W
    Shockwave.gd       # E
    Ultimate.gd        # R
  combat/
    Projectile.gd
    DamageNumber.gd
  world/
    Map.gd
    WaveSpawner.gd
    CameraRig.gd
  ui/
    MainMenu.gd
    HUD.gd
    Minimap.gd
    Shop.gd
    EndScreen.gd
  debug/
    AutoTest.gd        # test automatici e screenshot (vedi sezione 11)
scenes/
  main_menu.tscn
  game.tscn
  map.tscn
  units/*.tscn
  vfx/*.tscn
  ui/*.tscn
assets/
  models/  textures/  fonts/  sounds/
```

Regole sul codice:
- GDScript **con tipizzazione statica** (`var hp: float`, `func f(x: int) -> void`), `class_name` per le classi principali.
- Nessun numero "magico" sparso: tutte le costanti di bilanciamento stanno in `Game.gd` (o in un file `balance.gd`) raggruppate e commentate.
- Il progetto deve aprirsi senza errori né warning gravi nell'editor e da riga di comando.
- Le scene `.tscn` vanno scritte a mano in formato testo valido per Godot 4, oppure (preferibile per le scene complesse) costruite via codice in `_ready()`. Scegli l'approccio più robusto; evita file `.tscn` con riferimenti/UID rotti.

---

## 3. Stile grafico

**Stile deciso: 3D low-poly cartoon** — colorato, pulito, leggibile, a metà tra *Warcraft 3* e un *Clash Royale* in 3D. Personaggi dalle forme arrotondate e proporzioni "chunky" (teste grandi, armi grosse), colori pieni con texture minime/palette, luce calda da pomeriggio estivo, ombre morbide, bagliore sugli elementi magici. Visuale dall'alto inclinata (come Dota 2). **Niente** realismo, niente toni cupi/grigi (tranne la metà Dire della mappa, che resta comunque leggibile e saturata).

### 3.1 Asset
- **Fonte principale e unica (per coerenza di stile): KayKit di Kay Lousberg (CC0)** — https://kaylousberg.com/game-assets e https://kaylousberg.itch.io (anche su GitHub con il nome "KayKit"). Pacchetti da usare, in formato GLB/GLTF dentro `assets/models/`:
  - **"Character Pack: Adventurers"** → Kael (usa il **Mage**), cavalieri e maghi Radiant (Knight, Mage/Rogue ricolorati);
  - **"Character Pack: Skeletons"** → creep Dire (Skeleton Warrior, Skeleton Mage, ecc.);
  - **"Character Animations"** (rig e clip condivise: Idle, Walk, Run, attacchi melee/ranged, Spellcast, Hit, Death);
  - **"Forest Nature Pack"** / **"Dungeon Remastered"** / **"Medieval Hexagon Pack"** → alberi, rocce, cespugli, elementi delle basi, torri e decorazioni.
  - Registra licenza e fonte di ogni pacchetto in `assets/CREDITS.md`.
- Se un elemento manca in KayKit, usa **Kenney** (CC0) o **Quaternius** (CC0) **solo** se lo stile è compatibile (stessa densità di poligoni, colori pieni) e ritocca colori/materiali per uniformarlo. Mai mescolare stili visibilmente diversi.
- **Se il download fallisce o i modelli non si adattano bene, non bloccarti**: costruisci tutto proceduralmente con mesh primitive di Godot (`CapsuleMesh`, `BoxMesh`, `CylinderMesh`, `PrismMesh`, `SphereMesh`, `TorusMesh`) combinate in modo gradevole, con materiali `StandardMaterial3D` curati (albedo, roughness, emission per gli elementi magici). Il risultato deve comunque essere bello: proporzioni curate, palette coerente, piccoli dettagli (spalle, elmo, arma, cristallo sulla torre, ecc.).
- Ogni unità deve essere **immediatamente riconoscibile** per tipo e squadra:
  - Squadra **Radiant** (giocatore in allenamento / host): verde‑azzurro, dettagli dorati.
  - Squadra **Dire** (nemica / client): rosso‑viola, dettagli scuri.
  - Anello colorato a terra sotto ogni unità (decal o mesh piatta semitrasparente) con il colore della squadra; anello più grande e luminoso per l'eroe; anello di selezione/bersaglio quando passi il mouse sopra un nemico (cursore che diventa "attacco").

### 3.2 Ambiente e luci
- `WorldEnvironment` con: cielo procedurale (`ProceduralSkyMaterial`), luce ambientale morbida, **tonemap ACES/Filmic**, **glow/bloom** leggero, **SSAO**, nebbia leggera di profondità, correzione colore calda.
- `DirectionalLight3D` come sole inclinato, **ombre attive** (PSSM), luce calda.
- Terreno: un grande piano con texture o shader procedurale (erba con variazione di colore via noise), corsia di terra/pietra più chiara e ben visibile, bordi della mappa con alberi low-poly, rocce e cespugli (usa `MultiMeshInstance3D` per la vegetazione, centinaia di istanze con scala e rotazione casuali).
- Fiume decorativo al centro della mappa (piano con shader acqua semplice animato: scorrimento UV + fresnel), attraversato dalla corsia.
- Le basi hanno una piattaforma rialzata/decorata con il colore della squadra.

### 3.3 Feedback visivi (obbligatori)
- **Barre della vita** sopra ogni unità (verde per alleati, rossa per nemici, bordo più spesso per gli eroi; barra del mana blu sotto quella dell'eroe). Implementabili con `Sprite3D`/`SubViewport` o con un overlay 2D che proietta le posizioni 3D sullo schermo (scegli l'approccio più performante e nitido).
- **Numeri del danno** che salgono e svaniscono (bianchi per gli attacchi base, arancioni per le abilità, gialli e più grandi per l'oro guadagnato "+25").
- **Indicatore di click per il movimento**: piccolo anello verde animato a terra dove clicchi; rosso se clicchi su un nemico.
- **Effetti delle abilità** con `GPUParticles3D` (fuoco, scintille, onda d'urto, fumo), luci dinamiche temporanee (`OmniLight3D`) durante esplosioni e proiettili.
- **Proiettili** visibili per attacchi a distanza (torri, creep ranged, eroe ranged), con scia.
- **Morte delle unità**: l'unità si affloscia/si rimpicciolisce e svanisce, con sbuffo di particelle. La morte di una torre ha un'esplosione più grande e la torre crolla (scala/inclinazione animate). La distruzione dell'Antico ha un'esplosione finale spettacolare + rallentamento del tempo per 1 secondo.
- **Animazioni**: vedi sezione 3.4 (obbligatoria).
- **Indicatori di gittata**: tenendo premuto un tasto abilità (o in modalità "targeting") mostra un cerchio a terra con la gittata e un'area di effetto sotto il cursore.
- **Area di attacco delle torri**: cerchio rosso tenue che appare quando l'eroe si avvicina alla gittata di una torre nemica.

### 3.4 Animazioni (obbligatorie, devono essere "intriganti")

**Personaggi animati veri** (con scheletro e clip di animazione), non solo mesh statiche:
- Fonte: **KayKit** (vedi 3.1) — personaggi Adventurers e Skeletons con il pacchetto "Character Animations" (rig condiviso). Ripiego solo se KayKit non è scaricabile: **Quaternius** "Ultimate Animated Character Pack"/"Ultimate Monsters" (CC0), poi Kenney "Animated Characters"; annota la scelta in `DECISIONS.md`.
- Assegnazione dei modelli (sezione 0.1): Kael = Mage; creep Radiant = Knight (corpo a corpo) e Mage/Rogue (a distanza); creep Dire = Skeleton Warrior/Minion (corpo a corpo) e Skeleton Mage (a distanza); creep d'assedio (Fase 2) = golem o catapulta. Riapplica i colori di squadra sui materiali (con `instance shader parameters`, vedi 10.5) o con un rim light colorato.
- Usa `AnimationPlayer` + `AnimationTree` (state machine: idle → walk/run → attack → cast → hit → death), con **blend morbidi** tra gli stati (0.1–0.2 s).
- **Sincronizza l'animazione con la logica**: il danno dell'attacco base parte nel "punto d'impatto" della clip (es. al 40% della durata), non all'inizio; la velocità della clip di attacco si adatta alla velocità d'attacco; la velocità della camminata si adatta alla velocità di movimento (niente piedi che scivolano).
- Animazione di **lancio incantesimo** distinta per le abilità (braccia alzate, bagliore nelle mani), con le particelle che partono dalla mano (usa `BoneAttachment3D`).
- In rete, lo stato d'animazione è derivato dallo stato sincronizzato dell'unità (in movimento / attacca / lancia / morta) e riprodotto localmente.
- **Fallback** solo se proprio non riesci a ottenere modelli animati: animazioni procedurali via codice/`Tween` (dondolio e oscillazione degli arti nella camminata, affondo nell'attacco, braccia alzate nel lancio, caduta e dissolvenza nella morte) — annotalo in `DECISIONS.md` come limite.

**"Game feel" e animazioni di contorno** (rendono il gioco vivo):
- **Hit-stop** brevissimo (30–50 ms) e **scossa della telecamera** leggera quando esplodono la Meteora, una torre o l'Antico.
- Lampo bianco/rosso del materiale quando un'unità viene colpita; piccolo rinculo all'indietro.
- Edifici: cristallo della torre che pulsa e ruota lentamente; l'Antico ha una luce che "respira"; la fontana ha acqua/particelle che sgorgano.
- Ambiente vivo: alberi che ondeggiano col vento (vertex shader), acqua del fiume che scorre, lucciole/particelle ambientali, nuvole d'ombra che scorrono sul terreno (texture proiettata animata).
- Salita di livello: colonna di luce dorata sull'eroe + anello che si espande + suono.
- Rinascita: l'eroe appare alla fontana con un turbine di luce.
- UI animata: pulsanti del menu con hover (scala/brillio), barre della vita che calano con una "scia" ritardata (come in Dota), icone delle abilità che lampeggiano quando tornano disponibili, notifiche che entrano/escono con `Tween`, monete che volano verso il contatore dell'oro quando fai un last hit.
- Menu principale: telecamera che orbita lentamente sulla mappa con creep che combattono in sottofondo.

### 3.5 Audio: musica ed effetti sonori (obbligatori)

**Musica** (fonti CC0 o CC-BY, con attribuzione in `assets/CREDITS.md`):
- Fonti consigliate: **OpenGameArt.org** (filtra CC0), **Kevin MacLeod / incompetech.com** (CC-BY 4.0), **Pixabay Music**, pacchetti musicali di **Kenney** e **Tallbeard Studios**. Formato `.ogg` (loop).
- Brani necessari:
  1. **Menu principale**: epico/fantasy, atmosferico.
  2. **Partita – fase tranquilla**: orchestrale/fantasy di sottofondo, non invadente.
  3. **Partita – combattimento**: più intenso. Il gioco fa **crossfade** automatico verso questo brano quando l'eroe è in combattimento (ha inflitto o subito danni negli ultimi 5 s) e torna al brano tranquillo dopo 8 s di calma.
  4. **Vittoria** e **Sconfitta**: brevi stacchi (jingle).
- Se il download della musica fallisce: genera musica proceduralmente in GDScript con `AudioStreamGenerator` (accordi/arpeggi su una scala minore armonica, basso e percussioni semplici) oppure scrivi file `.wav` generati con uno script Python (es. `numpy`/`wave`) — deve comunque essere gradevole e non un beep fastidioso. Annotalo in `DECISIONS.md`.

**Effetti sonori** (es. Kenney "RPG Audio", "Impact Sounds", "Interface Sounds", "Sci-fi Sounds"; OpenGameArt; oppure generati con **sfxr/jsfxr** in modo procedurale):
- Attacco corpo a corpo (colpo di spada), attacco a distanza (lancio + impatto), sparo e impatto della torre.
- Ogni abilità: Palla di fuoco (lancio + esplosione), Scatto (whoosh), Onda d'urto (boom grave), Meteora (fischio in caduta + esplosione profonda).
- Morte di un creep, crollo di una torre, esplosione dell'Antico.
- Last hit / oro guadagnato (tintinnio di monete), salita di livello, rinascita, acquisto nel negozio, abilità non pronta / mana insufficiente (suono di errore discreto), click di movimento, click e hover dei pulsanti UI.
- Voci/notifiche annunciatore opzionali (testo a schermo basta).
- **Audio posizionale 3D** (`AudioStreamPlayer3D`) per i suoni nel mondo, con attenuazione in base alla distanza dalla telecamera; suoni UI in 2D.
- Leggera variazione casuale di pitch (±8%) per evitare ripetitività; limite al numero di suoni uguali simultanei (pool di player).
- **Bus audio** separati: Master, Musica, Effetti, UI — con slider di volume nelle Impostazioni (salvati in `user://settings.cfg`) e tasto `M` per silenziare la musica.

---

## 4. Mappa

- Dimensione indicativa: 200 × 200 unità di gioco (1 unità = 1 metro).
- **Una corsia centrale diagonale** (da angolo in basso a sinistra = base Radiant, ad angolo in alto a destra = base Dire), come la corsia centrale di Dota. La corsia è definita da una lista di **waypoint** (`Path3D` o array di `Vector3`) che i creep seguono.
- Per squadra:
  - **2 torri** lungo la corsia (Torre T1 più avanzata, Torre T2 vicino alla base).
  - **1 Antico** (la base) nella propria piattaforma.
  - **Fontana** dietro l'Antico: punto di rinascita; rigenera rapidamente vita e mana degli alleati vicini (+5% della vita massima al secondo); spara ai nemici che si avvicinano con danno altissimo (impedisce di "campeggiare" la base).
- Ostacoli decorativi (alberi, rocce) ai lati della corsia che bloccano il passaggio.
- **Navigazione**: usa `NavigationRegion3D` con navmesh generata (bake a runtime in `_ready()` o pre-generata) e `NavigationAgent3D` per eroi e creep, con **avoidance** attivata così le unità non si sovrappongono. Se il bake dà problemi, ripiega su movimento diretto + separazione semplice (forze di repulsione tra unità vicine), ma il risultato deve essere fluido e senza unità incastrate.

---

## 5. Unità e bilanciamento (valori iniziali)

Tutti i valori in `Game.gd`, facilmente modificabili.

### 5.1 Eroe: Kael, il Piromante (attaccante a distanza)

Attacco base: **dardo di fuoco** dal cristallo del bastone (proiettile arancione con scia). Profilo: agile e fragile, tanto danno dalle abilità, poca resistenza.
| Statistica | Livello 1 | Per livello |
|---|---|---|
| Vita | 600 | +80 |
| Rigenerazione vita | 2/s | +0.2 |
| Mana | 300 | +40 |
| Rigenerazione mana | 1.5/s | +0.15 |
| Danno attacco | 45 | +4 |
| Velocità d'attacco | 1 attacco ogni 1.3 s | -0.03 s (min 0.7) |
| Gittata attacco | 6 | — |
| Velocità movimento | 7 m/s | — |
| Armatura | 2 | +0.3 |

- Livello massimo 10. Esperienza necessaria: `100 * livello` per salire di livello.
- Esperienza: si guadagna quando un'unità nemica muore entro 12 m dall'eroe (creep: 40 XP, torre: 150 XP, eroe nemico: 200 + 20 × livello).
- Oro: +1 oro al secondo passivo; **colpo finale** (last hit) su un creep: 35–45 oro; torre distrutta: 200 oro a tutta la squadra; uccisione di un eroe: 250 oro.
- **Riduzione del danno da armatura** (formula Dota semplificata): `moltiplicatore = 1 - (0.06 * armatura) / (1 + 0.06 * abs(armatura))`.
- Morte: tempo di rinascita = `4 + 2 * livello` secondi, rinascita alla fontana. Mostra il conto alla rovescia sull'HUD con lo schermo desaturato.

### 5.2 Abilità dell'eroe (Q, W, E, R)
Ogni abilità ha: costo di mana, ricarica, gittata, tipo di bersaglio, effetto visivo, suono. Si sbloccano/potenziano con i **punti abilità** (1 per livello; R sbloccabile dal livello 6). Al livello 1 il giocatore ha 1 punto da spendere (per comodità in allenamento, Q parte già al livello 1). I punti si spendono con `Ctrl+Q/W/E/R` oppure cliccando il "+" sopra l'icona.

1. **Q — Palla di fuoco** *(Kael scaglia una sfera infuocata dal bastone)* (proiettile verso un punto): proiettile che viaggia in linea retta (gittata 14, velocità 25 m/s) ed esplode al primo nemico colpito o a fine corsa, area 3 m. Danno 90/150/210/270. Mana 80. Ricarica 6 s.
2. **W — Scatto** *(scompare in uno sbuffo di braci e riappare in un vortice di fiamme)* (teletrasporto verso un punto): teletrasporto istantaneo fino a 10 m. Particelle alla partenza e all'arrivo. Mana 60. Ricarica 14/12/10/8 s.
3. **E — Onda d'urto** *(pianta il bastone a terra: anello di fuoco arcano azzurro‑arancio che si espande)* (area attorno all'eroe): onda circolare di raggio 5 m che infligge 60/100/140/180 danni e **rallenta** i nemici del 40% per 2 s. Mana 100. Ricarica 10 s.
4. **R — Meteora** *(Fase 2; evoca un frammento di cristallo infuocato dal cielo)* (area su un punto, ultimate): dopo 1 s di ritardo (cerchio di avviso rosso a terra) cade una meteora che infligge 300/450/600 danni in un raggio di 6 m e **stordisce** per 1.5 s. Mana 200. Ricarica 60/50/40 s.

### 5.3 Creep
- Ondata ogni **30 s** (la prima a 5 s dall'inizio), per entrambe le squadre, dalla rispettiva base.
- Ogni ondata: **3 creep corpo a corpo + 1 creep a distanza**. Ogni 5 ondate si aggiunge un **creep d'assedio** (lento, molto danno contro le torri).
- Ogni 5 minuti i creep diventano più forti (+10% vita e danno).

| Tipo | Vita | Danno | Intervallo attacco | Gittata | Velocità | Armatura |
|---|---|---|---|---|---|---|
| Corpo a corpo | 550 | 20 | 1.0 s | 1.5 | 5 | 2 |
| A distanza | 300 | 24 | 1.0 s | 5 | 5 | 0 |
| Assedio | 900 | 40 (×2.5 contro edifici) | 2.5 s | 7 | 3.5 | 0 |

- **IA dei creep**: seguono i waypoint della corsia; se un nemico entra nel raggio di aggressione (8 m) lo attaccano; priorità bersagli: (1) l'eroe nemico che ha appena attaccato un eroe alleato vicino, (2) il creep nemico più vicino, (3) le torri / l'Antico, (4) l'eroe nemico. Quando il bersaglio muore o esce dal raggio di inseguimento (12 m dal punto in cui hanno lasciato la corsia), tornano a seguire la corsia.
- **Negazione (deny)**: l'eroe può attaccare i propri creep sotto il 50% di vita (Attacco forzato con `A` + click); se li uccide il nemico non prende oro ed esperienza piena. (Utile soprattutto in 1v1.)

### 5.4 Torri, Antico, Fontana
| Edificio | Vita | Armatura | Danno | Intervallo | Gittata |
|---|---|---|---|---|---|
| Torre T1 | 1800 | 10 | 110 | 1.0 s | 8 |
| Torre T2 | 2200 | 12 | 140 | 1.0 s | 8 |
| Antico | 4000 | 15 | — | — | — |
| Fontana | invulnerabile | — | 300 | 0.3 s | 10 |

- **Protezione a cascata**: la T2 è invulnerabile finché la T1 della stessa squadra è in piedi; l'Antico è invulnerabile finché la T2 è in piedi. Mostra un'icona/scudo trasparente sull'edificio invulnerabile.
- **IA delle torri**: attaccano il nemico più vicino; ma se un eroe nemico attacca un eroe alleato entro la loro gittata, cambiano bersaglio su quell'eroe (regola Dota). Le torri sparano un proiettile luminoso visibile.

---

## 6. Controlli (stile Dota)

| Input | Azione |
|---|---|
| Click destro a terra | Muovi |
| Click destro su nemico | Attacca (insegue e attacca automaticamente) |
| `A` + click sinistro | Attacco forzato / attacco-movimento (attacca il primo nemico che incontra) |
| `S` | Fermati |
| `Q` `W` `E` `R` | Abilità (prima pressione = mira, click sinistro = lancia; click destro / Esc = annulla). Opzione "lancio rapido" attivabile nelle impostazioni. |
| `Ctrl` + `Q/W/E/R` | Spendi punto abilità |
| `B` | Apri/chiudi negozio (acquistabile solo vicino alla fontana) |
| `1`–`6` | Usa oggetto attivabile nello slot |
| Mouse ai bordi dello schermo | Scorri la telecamera |
| Frecce / `WASD`-alternativa disattivata (per non confliggere con A/S) | Scorri la telecamera con le frecce |
| Rotella | Zoom (limitato tra un minimo e un massimo) |
| `Spazio` (tenuto) | Centra la telecamera sull'eroe |
| `Y` | Blocca/sblocca la telecamera sull'eroe |
| Click sulla minimappa | Sposta la telecamera; click destro sulla minimappa = muovi l'eroe lì |
| `Tab` | Tabella punteggio (uccisioni, morti, last hit, oro, livello) |
| `F10` / `Esc` | Menu di pausa (in allenamento mette in pausa il gioco; in rete no) |
| `F12` | Screenshot salvato in `screenshots/` |

- Il cursore del mouse cambia forma: normale, attacco (spada rossa) su un nemico, mira durante il targeting delle abilità.

---

## 7. Telecamera

- `Camera3D` prospettica, angolo ~55° verso il basso, leggero campo visivo stretto (FOV ~45°) per un look "Dota".
- Scorrimento ai bordi dello schermo (margine 10 px) e con le frecce, movimento morbido (interpolazione).
- Zoom con la rotella tra due altezze; limiti ai bordi della mappa.
- All'inizio della partita e alla rinascita è centrata sull'eroe.

---

## 8. Interfaccia utente

### 8.1 Menu principale
- Schermata con titolo **"Ancients Clash"** e sottotitolo *"Le Terre di Aethra"*, Kael in posa idle in primo piano, sfondo con la mappa 3D che ruota lentamente alle spalle del menu.
- Pulsanti:
  - **Allenamento** (single player).
  - **Ospita partita** (campo porta, default `7777`; mostra gli **IP locali** della macchina per comunicarli all'amico; stato "In attesa dell'avversario...").
  - **Unisciti** (campi IP e porta; ultimo IP usato salvato in `user://settings.cfg`).
  - **Impostazioni**: volume, schermo intero/finestra, qualità ombre, lancio rapido sì/no, sensibilità di scorrimento.
  - **Esci**.
- Campo **nome giocatore** (salvato).

### 8.2 HUD in partita (stile Dota, in basso al centro)
- Ritratto dell'eroe con livello e barra dell'esperienza.
- Barre grandi di vita e mana con valori numerici e rigenerazione.
- 4 icone delle abilità (Q/W/E/R) con: tasto, livello (pallini), **ricarica come spicchio scuro che ruota + secondi rimanenti**, grigio se manca il mana, costo in mana. Icone disegnate proceduralmente o con simboli/emoji/SVG semplici ma gradevoli.
- 6 slot per gli oggetti.
- Statistiche: danno, armatura, velocità di movimento.
- Oro in alto a destra o vicino agli slot.
- **Minimappa** in basso a sinistra: vista dall'alto stilizzata (corsia, fiume, basi), puntini colorati per unità ed edifici, rettangolo della visuale della telecamera.
- In alto al centro: **orologio di gioco**, punteggio uccisioni delle due squadre, conto alla rovescia per la prossima ondata.
- Notifiche al centro dello schermo: "Prima ondata in arrivo!", "La tua torre è sotto attacco!", "Torre nemica distrutta!", "Hai ucciso l'eroe nemico!", ecc.
- Tooltip passando il mouse sopra abilità e oggetti (descrizione, danno per livello, costo, ricarica).
- Il tema UI deve essere coerente: pannelli scuri semitrasparenti con bordi dorati, font leggibile (usa un font open-source es. scaricato da Google Fonts con licenza OFL; altrimenti quello di default), angoli arrotondati (`StyleBoxFlat`).

### 8.3 Negozio (`B`, utilizzabile solo entro 15 m dalla fontana)
Oggetti (statistiche sommate all'eroe, max 6 oggetti):
| Oggetto | Costo | Effetto |
|---|---|---|
| Spada lunga | 400 | +15 danno |
| Armatura di cuoio | 350 | +4 armatura |
| Stivali della velocità | 450 | +1.5 velocità movimento |
| Gemma della vitalità | 500 | +250 vita |
| Cristallo arcano | 500 | +200 mana, +1 rigenerazione mana |
| Anello di rigenerazione | 300 | +4 rigenerazione vita |
| Pozione di cura (consumabile, attivabile 1–6) | 100 | ripristina 400 vita in 8 s (si interrompe se colpiti da un eroe) |
| Pozione di mana (consumabile) | 100 | ripristina 250 mana in 8 s |
| Lama del vampiro | 1200 | +20 danno, 15% rubavita sugli attacchi base |

- Doppio click o click destro sull'oggetto per comprare; possibilità di vendere al 50% del prezzo.

### 8.4 Fine partita
- Schermata "**VITTORIA**" / "**SCONFITTA**" con statistiche finali (durata, uccisioni, morti, last hit, deny, oro totale, danni inflitti a eroi ed edifici) e pulsanti "Rigioca" e "Menu principale".

---

## 9. Modalità Allenamento (single player) — priorità assoluta

- L'eroe del giocatore è Radiant e nasce alla fontana Radiant.
- Creep, torri, Antico e fontana per **entrambe** le squadre funzionano normalmente. **Nessun eroe nemico.**
- Si vince distruggendo l'Antico Dire. Si perde se l'Antico Radiant viene distrutto (possibile se il giocatore resta inattivo a lungo, grazie ai creep d'assedio e al rafforzamento dei creep nel tempo).
- Funziona **senza nessuna rete**: usa la stessa logica di gioco della modalità online, eseguita in locale (es. il giocatore è contemporaneamente "server" e client tramite `OfflineMultiplayerPeer`, che è il default di Godot), così il codice non si sdoppia.
- Opzioni di allenamento nel menu di pausa (utili per provare): "Oro +1000", "Livello +1", "Azzera ricariche", "Invulnerabilità sì/no", "Velocità di gioco ×1 / ×2". Contrassegnale chiaramente come opzioni di allenamento (disponibili solo in single player).

---

## 10. Modalità in rete 1 contro 1

### 10.1 Architettura
- **Server autoritativo** con l'API multiplayer di alto livello di Godot 4 (`ENetMultiplayerPeer`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPC).
- L'**host** è sia server sia giocatore (peer id 1, squadra Radiant). Il **client** è squadra Dire.
- Il client invia **solo comandi** (muovi verso X, attacca unità N, lancia abilità K su punto/bersaglio, compra oggetto, spendi punto abilità) tramite RPC `any_peer` verso il server. Il server **convalida** ogni comando (il mittente controlla davvero quell'eroe? l'abilità è pronta? c'è abbastanza mana/oro? la gittata è rispettata?) e lo esegue.
- **Tutta la simulazione** (movimento, IA dei creep, danni, ondate, morte, oro, XP) avviene **solo sul server**, a **tick fisso** (vedi 10.4). I client ricevono lo stato tramite **snapshot compatti** e lo **interpolano** (vedi 10.4).
- Gli effetti puramente visivi (particelle, numeri del danno, suoni) sono derivati dagli eventi contenuti negli snapshot o da RPC non affidabili, e riprodotti localmente.
- Lo spawn/despawn di creep, proiettili ed eroi avviene tramite eventi affidabili con **id univoci assegnati dal server** (o `MultiplayerSpawner` se si dimostra efficiente nei test).
- Il client vede **immediatamente** l'indicatore di click quando dà un ordine (feedback locale), e il proprio eroe si muove subito grazie alla predizione (10.4).

### 10.2 Flusso di connessione
1. L'host clicca "Ospita": crea il server sulla porta scelta (default 7777, UDP), mostra i propri IP locali (es. ottenuti con `IP.get_local_addresses()`, filtrando IPv4 privati) e attende.
2. Il client inserisce IP e porta e clicca "Unisciti". Timeout di connessione di 10 s con messaggio di errore chiaro.
3. Quando entrambi sono connessi: schermata **lobby** con i due nomi e un pulsante "Pronto" per ciascuno; quando entrambi sono pronti, l'host avvia la partita, conto alla rovescia 3‑2‑1 e caricamento della mappa per entrambi.
4. **Disconnessione** dell'avversario durante la partita: messaggio "L'avversario si è disconnesso" → vittoria a tavolino e ritorno al menu. Se cade l'host, il client vede "Connessione con l'host persa" e torna al menu.
5. Controllo di versione: al collegamento il client invia la versione del gioco; se diversa da quella dell'host, la connessione viene rifiutata con un messaggio esplicito.

### 10.3 Gioco tra due macchine
- In `README.md` spiega:
  - come giocare in LAN (stessa rete, IP locale dell'host);
  - come giocare via internet: (a) **Tailscale/ZeroTier** (consigliato, nessuna configurazione del router), oppure (b) port forwarding UDP 7777 sul router dell'host;
  - eventuale apertura della porta nel firewall Linux (`ufw allow 7777/udp` o equivalente per `firewalld`/`nftables`), solo come istruzione per l'utente: **non** modificare tu il firewall.
- Il gioco esportato deve poter essere copiato sulla macchina dell'amico (anche lui Linux) e lanciato senza installare Godot.

### 10.4 Netcode anti-lag (obbligatorio)

- **Tick fisso del server: 30 Hz** (`Engine.physics_ticks_per_second = 30` o accumulatore dedicato), indipendente dal framerate di rendering. La logica di gioco è **deterministica rispetto al tick** (niente dipendenza dal `delta` del rendering).
- **Snapshot di stato a 20 Hz** dal server ai client, inviati su canale **unreliable ordered** (`MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED`, canale dedicato). Contenuto compatto, impacchettato con `PackedByteArray`/`StreamPeerBuffer`:
  - per ogni unità: id (u16), posizione x/z quantizzata (es. i16 con precisione 1 cm o 16 bit su tutta la mappa), rotazione (u8), vita e mana in percentuale o valore quantizzato (u16), flag di stato (u8: in movimento/attacca/lancia/stordito/morto);
  - **delta compression**: invia solo le unità cambiate rispetto all'ultimo snapshot confermato dal client (oppure, versione più semplice, salta le unità ferme e invariate e invia uno snapshot completo ogni 1 s);
  - numero di tick del server nello snapshot.
- **Eventi affidabili** (`TRANSFER_MODE_RELIABLE`, canale separato) solo per ciò che non si può perdere: spawn/despawn, morte, acquisti, salita di livello, fine partita. Mai per posizioni.
- **Interpolazione sul client**: rendering ritardato di ~100 ms (2 snapshot) con interpolazione lineare tra snapshot; **estrapolazione** breve (max 200 ms) se uno snapshot manca; poi blocco morbido.
- **Predizione lato client per il proprio eroe**: il movimento dell'eroe del client parte subito localmente (stesso codice di movimento del server); quando arriva lo stato autoritativo, **riconciliazione**: se l'errore è piccolo (< 0.5 m) correzione morbida in 100–200 ms, se grande "snap" immediato. Attacchi e abilità **non** si predicono come danni, ma l'animazione di lancio parte subito (il danno arriva dal server).
- **Comandi del client** inviati come RPC reliable piccoli (pochi byte), con numero di sequenza; il server ignora comandi duplicati o fuori ordine.
- **Limiti di banda**: obiettivo **< 30 KB/s per client** nel caso peggiore (tante unità in corsia). Stampa la banda media e massima nell'autotest di rete.
- **Robustezza**: timeout di disconnessione ENet configurato (es. 5–10 s), gestione di pacchetti malformati (ignora, non crashare), nessuna RPC che accetti oggetti/Node dal client — solo tipi semplici validati.
- **Indicatore di rete nell'HUD**: ping (ms) e perdita pacchetti, colorati (verde < 80 ms, giallo < 150, rosso oltre).

### 10.5 Prestazioni e stabilità (obbligatorio)

**Prestazioni di rendering e simulazione:**
- Obiettivo: **60 FPS stabili** (frame time < 16.6 ms, nessun picco > 33 ms) su un PC medio con GPU integrata recente, in impostazione "Media"; **≥ 120 FPS** su hardware discreto.
- **Preset di qualità** in Impostazioni (Bassa / Media / Alta), salvati in `user://settings.cfg`, default **Media**:
  - Bassa: renderer `gl_compatibility` opzionale o Forward+ con ombre a bassa risoluzione, niente SSAO/glow/nebbia volumetrica, vegetazione ridotta al 30%, particellari ridotti, risoluzione 3D scalabile (`scaling_3d_scale` 0.75).
  - Media: ombre medie, glow, niente SSAO, vegetazione 70%.
  - Alta: tutto attivo.
  - Opzioni: VSync on/off, limite FPS (60/120/144/illimitato), schermo intero.
- **Pool di oggetti** per proiettili, numeri del danno, particellari, suoni, anelli di click: niente `instantiate()`/`queue_free()` continui durante la partita.
- **IA a intervalli**: ricerca bersagli dei creep e delle torri ogni 0.15–0.25 s (sfasata tra le unità per evitare picchi), non ogni frame. Ricerca dei vicini con **griglia spaziale** (celle da 8 m) o con `Area3D` e layer/mask di collisione corretti, mai scansioni O(n²) di tutte le unità ad ogni frame.
- Navigazione: richieste di percorso solo quando cambia la destinazione o il bersaglio si sposta di > 1 m; per i creep in corsia, seguire i waypoint con steering semplice + avoidance (`NavigationAgent3D` avoidance o separazione propria), ricalcolo percorso solo quando lasciano la corsia.
- Rendering: **MultiMesh** per vegetazione e rocce; LOD/visibility range (`visibility_range_end`) per oggetti decorativi; pochi materiali condivisi (niente materiali unici per istanza: usa `instance shader parameters` per i colori di squadra); luci dinamiche temporanee limitate (max 4 contemporanee, con pool); ombre solo dalla luce del sole; particellari `GPUParticles3D` con numero di particelle contenuto.
- Barre della vita: un unico overlay 2D (Control che disegna tutte le barre in `_draw()`) o `Sprite3D` billboard condivisi — scegli quello che misuri più veloce.
- Limite massimo di unità vive contemporaneamente (es. 60 creep): se superato, le ondate successive aspettano (salvaguardia contro accumuli in partite lunghe).
- Niente `print` nel ciclo di gioco in build di rilascio; log solo in debug.

**Stabilità:**
- **Nessun crash e nessun errore a console** durante una partita lunga. Uso sistematico di `is_instance_valid()` prima di accedere a bersagli che potrebbero essere morti; i riferimenti ai bersagli si tengono per **id** e si risolvono tramite un registro delle unità, non tenendo puntatori a nodi liberati.
- Morte delle unità gestita in due fasi (stato "morto" → rimozione dopo l'animazione) senza lasciare segnali collegati o timer appesi.
- Nessuna perdita di memoria: numero di nodi e memoria statica stabili nel tempo (`Performance.OBJECT_NODE_COUNT`, `Performance.MEMORY_STATIC`).
- Il gioco non si blocca mai in attesa di rete: tutte le operazioni di rete sono non bloccanti.
- Gestione pulita di uscita dalla partita / ritorno al menu / nuova partita (nessuno stato residuo, nessun nodo orfano).

### 10.6 Eroe nemico in 1v1
- Entrambi i giocatori usano lo stesso eroe (stesse abilità), con colori diversi per squadra. Regole di uccisione eroi, oro e XP come da sezione 5. Le torri difendono dagli eroi secondo la regola della sezione 5.4.

---

## 11. Verifica automatica (da fare tu, senza l'utente)

Non hai modo di giocare interattivamente, quindi costruisci strumenti per verificare il gioco da solo:

1. **Controllo errori**: esegui `godot --headless --path . --quit` (o `--editor --quit` per forzare l'import degli asset) e assicurati che non ci siano errori di parsing/script nell'output. Correggi tutti gli errori e i warning rilevanti.
2. **Modalità di test automatico** (`scripts/debug/AutoTest.gd`), attivabile con argomenti utente dopo `--` (letti con `OS.get_cmdline_user_args()`):
   - `-- --autotest-training`: avvia direttamente l'allenamento, accelera il tempo (`Engine.time_scale`), simula ordini dell'eroe (avanzare lungo la corsia, attaccare creep, usare Q/W/E/R, comprare un oggetto), e verifica tramite `assert`/log che: le ondate nascono, i creep combattono e muoiono, l'eroe guadagna oro e XP e sale di livello, le abilità consumano mana e vanno in ricarica, le torri attaccano, le protezioni a cascata funzionano, l'eroe muore e rinasce, la partita termina con vittoria quando l'Antico nemico viene distrutto (puoi forzare con danno di debug). Stampa un riepilogo `AUTOTEST OK` / `AUTOTEST FAIL: <motivo>` ed esci con codice 0/1.
   - `-- --autotest-net-host` e `-- --autotest-net-client`: avvia un host e un client **in due processi separati sulla stessa macchina** (127.0.0.1), simula la lobby, avvia la partita, il client invia comandi di movimento e attacco, e verifica che lo stato si sincronizzi (posizione dell'eroe del client cambia sul server e viene vista da entrambi, i creep esistono su entrambi con gli stessi id, i danni sono coerenti). Entrambi stampano `NETTEST OK`/`FAIL` ed escono. Lanciali in background da bash con un timeout e controlla l'output.
3. **Screenshot per controllare la grafica**: aggiungi `-- --screenshot <file.png> --at <secondi>` che avvia l'allenamento, aspetta il tempo indicato (con l'azione in corso: creep che combattono, un'abilità lanciata), salva uno screenshot della viewport ed esce. Il display grafico è disponibile (Wayland/Hyprland); se l'esecuzione non headless non funzionasse, prova con `--rendering-driver opengl3` o con `xvfb-run`, o con `--write-movie`. Genera almeno questi screenshot in `screenshots/`:
   - menu principale;
   - inizio partita con eroe alla fontana;
   - scontro tra creep in corsia;
   - eroe che lancia un'abilità (con particelle visibili);
   - torre che spara;
   - HUD con negozio aperto;
   - schermata di vittoria.
   Per le animazioni genera anche **sequenze di fotogrammi** (es. 6 screenshot a 0.1 s di distanza durante un attacco e durante una camminata) e controlla che le pose cambino davvero e che i piedi non scivolino.
   **Guarda tu stesso gli screenshot** (leggendo i file immagine) e migliora la grafica finché non è davvero gradevole: niente oggetti che compenetrano il terreno, luci troppo scure/bruciate, UI tagliata o sovrapposta, testi illeggibili, colori di squadra poco distinguibili. Fai almeno 2 cicli di revisione grafica.
4. **Prestazioni, lag e stabilità** (da rieseguire dopo ogni fase e dopo ogni aggiunta di Fase 2):
   - **Benchmark** `-- --benchmark`: allenamento con scenario di carico fisso (5 ondate per lato in corsia contemporaneamente, abilità lanciate a ripetizione, telecamera sullo scontro) per 60 s, per ciascun preset di qualità. Stampa FPS medio, **1% low**, frame time massimo, tempo medio del tick di simulazione (`Performance.TIME_PROCESS`/`TIME_PHYSICS_PROCESS`), numero di draw call (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`). Limiti: FPS medio ≥ 60 e 1% low ≥ 45 in "Media" sulla macchina di sviluppo; tick di simulazione < 4 ms; draw call < 1000. Salva i risultati in `benchmark_results.md` (con cronologia per fase).
   - **Test con lag simulato**: aggiungi un simulatore di rete integrato (opzione `-- --netsim latency=120,jitter=30,loss=3`) che ritarda/scarta i pacchetti in uscita e in entrata lato client. Ripeti `--autotest-net-*` con: 0 ms; 80 ms; 150 ms + 30 ms jitter + 3% perdita; 250 ms + 5% perdita. Verifica che: il movimento dell'eroe del client resti fluido (errore di riconciliazione medio < 0.3 m nei casi fino a 150 ms), i creep visti dal client non "teletrasportino" (salto massimo per frame sotto una soglia ragionevole), la partita non si desincronizzi, la banda resti < 30 KB/s. Stampa queste metriche.
   - **Test di durata (soak test)** `-- --soak`: partita di allenamento simulata di 30 minuti di gioco (con `Engine.time_scale` accelerato) e, separatamente, partita in rete host+client di 10 minuti. Verifica: zero errori/eccezioni in console, numero di nodi e memoria stabili (crescita < 5% tra minuto 5 e fine), nessun creep incastrato più di 10 s, nessun calo progressivo degli FPS.
   - **Test di robustezza di rete**: client che si disconnette brutalmente (kill del processo) a metà partita, host che si chiude, riconnessione al menu e nuova partita senza riavviare il gioco: nessun crash, nessuno stato residuo.
   - Se un limite non è rispettato: **profila** (profiler di Godot / misure manuali con `Time.get_ticks_usec()`), individua il collo di bottiglia e correggilo, semplificando se necessario la grafica o la funzionalità responsabile. Mai lasciare un limite violato senza annotarlo in `DECISIONS.md`.
5. **Esportazione**: crea `export_presets.cfg` con un preset "Linux" e uno script `build.sh` che esporti `build/AncientsClash.x86_64` (+ `.pck` o pck incorporato). Esegui l'esportazione e verifica che l'eseguibile si avvii (es. lanciandolo con `-- --autotest-training`).

---

## 12. Criteri di completamento (tutti obbligatori)

- [ ] Godot 4 installato (o binario locale) e funzionante; versione annotata in `DECISIONS.md`.
- [ ] Il progetto si apre/avvia senza errori di script.
- [ ] `./run.sh` avvia il gioco sul menu principale.
- [ ] La modalità **Allenamento** è giocabile dall'inizio alla fine: movimento con click destro, attacco automatico, last hit, 4 abilità con effetti, livelli, oro, negozio, torri con protezione a cascata, fontana, morte e rinascita, vittoria/sconfitta.
- [ ] `--autotest-training` stampa `AUTOTEST OK`.
- [ ] Host e client sulla stessa macchina si collegano, passano dalla lobby e giocano; `--autotest-net-host`/`--autotest-net-client` stampano `NETTEST OK`.
- [ ] Gli screenshot in `screenshots/` mostrano una grafica curata e coerente (verificati e migliorati da te).
- [ ] Eroe e creep hanno animazioni vere (idle, camminata, attacco, lancio, morte) sincronizzate con la logica; gli effetti di "game feel" della sezione 3.4 sono presenti.
- [ ] Musica nel menu e in partita (con crossfade combattimento/calma), jingle di vittoria/sconfitta, effetti sonori per tutte le azioni della sezione 3.5, volumi regolabili. L'autotest verifica che i file audio si carichino e che i player vengano avviati senza errori.
- [ ] Fase 1 completa e stabile; elementi di Fase 2 aggiunti solo se rispettano i limiti (quelli scartati sono elencati in `DECISIONS.md`).
- [ ] Benchmark, test con lag simulato, soak test e test di robustezza di rete (sezione 11, punto 4) superati, con risultati in `benchmark_results.md`.
- [ ] Preset di qualità Bassa/Media/Alta funzionanti; indicatore di ping nell'HUD.
- [ ] `./build.sh` produce un eseguibile Linux in `build/` che si avvia.
- [ ] `README.md` in **italiano** con: requisiti, come avviare (`./run.sh` o eseguibile), controlli completi, come ospitare/unirsi in LAN e via internet (Tailscale, port forwarding), come lanciare i test automatici, come modificare il bilanciamento, struttura del progetto.
- [ ] `DECISIONS.md` con le scelte prese in autonomia e gli eventuali limiti noti.
- [ ] `assets/CREDITS.md` con licenze e fonti degli asset di terze parti (se usati).
- [ ] Inizializza un repository git nella cartella, con `.gitignore` adatto a Godot (`.godot/`, `build/`, `tools/`, `screenshots/` opzionale) e un commit finale con tutto il lavoro.

---

## 13. Ordine di lavoro consigliato

**Fase 1 — Nucleo**
1. Setup Godot + scheletro del progetto + autoload + `run.sh`. Imposta **subito** l'architettura a tick fisso e "server autoritativo + client che visualizza" anche per l'allenamento (in locale), così la rete non va riprogettata dopo.
2. Download degli asset (modelli animati, musica, effetti sonori) con licenze annotate; mappa, terreno, luci, telecamera, preset di qualità (subito con screenshot di controllo e primo benchmark).
3. Registro delle unità per id, classe `Unit`, eroe con movimento click destro, navigazione e `AnimationTree`.
4. Combattimento: attacco base, proiettili (con pool), danno, armatura, morte, barre della vita, numeri del danno.
5. Creep e ondate con IA a intervalli + griglia spaziale; torri, Antico, fontana; protezione a cascata; vittoria/sconfitta. **Benchmark.**
6. Oro, XP, livelli, abilità Q/W/E con VFX; negozio con 5 oggetti.
7. HUD essenziale, minimappa, fine partita, menu principale e impostazioni; musica ed effetti sonori base.
8. Autotest dell'allenamento + revisione grafica tramite screenshot (almeno 2 cicli). **Benchmark + soak test.**
9. Multiplayer: host/join, lobby, snapshot compatti, interpolazione, predizione e riconciliazione, convalida dei comandi, disconnessioni, indicatore ping; autotest di rete **con lag simulato** e test di robustezza.
10. Esportazione + verifica dell'eseguibile. A questo punto la Fase 1 è consegnabile: **fai un commit git**.

**Fase 2 — Arricchimento (uno alla volta, con test dopo ciascuno)**
11. Elementi della lista di Fase 2 in ordine di valore per il giocatore: abilità R → creep d'assedio e rafforzamento → oggetti restanti → crossfade musicale e effetti di game feel → resto. Dopo ciascuno: controllo errori, benchmark, test di rete con lag; commit git se tutto è nei limiti, altrimenti semplifica o scarta.

**Chiusura**
12. Esportazione finale, README, DECISIONS, CREDITS, `benchmark_results.md`, commit git finale.

Durante tutto il lavoro: dopo ogni passo esegui il controllo errori (11.1) e correggi subito; non accumulare errori. Se qualcosa non funziona dopo vari tentativi, trova un'alternativa più semplice che soddisfi comunque i requisiti, annotala in `DECISIONS.md` e vai avanti. **In caso di dubbio tra "più bello" e "più fluido/stabile", scegli sempre più fluido/stabile.**
