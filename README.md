# Dawn & Ash — Le Terre di Aethra

MOBA minimale in stile Dota 2, in 3D stilizzato (personaggi cartoon, terreno con texture), per Linux e Windows. Guidi **Kael, il Piromante** della Lega dell'Alba
contro il Culto della Cenere: distruggi le torri e l'**Antico** nemico. Si gioca in **allenamento** (contro creep e torri)
oppure **1 contro 1 in rete**, con una delle due macchine che fa da host.

Fatto con **Godot 4.7** e GDScript. Modelli KayKit, texture del terreno ambientCG, suoni Kenney e musica OpenGameArt, tutti con licenza libera (vedi `assets/CREDITS.md`).

---

## Per giocare subito (senza installare niente)

### Windows

Scarica `DawnAndAsh-0.1.0-windows-x86_64.zip` (in `build/`, creato da `./build.sh`), estrai la cartella dove vuoi
e fai doppio click su `DawnAndAsh.exe`. Non serve installare nulla: per toglierlo basta cancellare la cartella.

- L'eseguibile non è firmato: al primo avvio Windows mostra "Windows ha protetto il PC".
  Clicca **Ulteriori informazioni → Esegui comunque**.
- Alla prima partita in rete il firewall di Windows chiede il permesso: consenti l'accesso (almeno alle reti private).
- Requisiti: Windows 10/11 a 64 bit con driver video aggiornati.

### Linux

**Installer** (consigliato): scarica `DawnAndAsh-0.1.0-linux-x86_64.run` (in `build/`, creato da `./build.sh`) e avvialo:

```bash
sh DawnAndAsh-0.1.0-linux-x86_64.run
```

Non serve essere root né installare altro. Il gioco va in `~/.local/opt/dawn-and-ash`, compare nel menu delle applicazioni
e si avvia anche col comando `dawn-and-ash`. Per toglierlo: `sh ~/.local/opt/dawn-and-ash/uninstall.run --uninstall`.

**Senza installare**: l'eseguibile `build/DawnAndAsh.x86_64` contiene tutto il gioco:

```bash
chmod +x DawnAndAsh.x86_64
./DawnAndAsh.x86_64
```

Requisiti: Linux a 64 bit con driver video aggiornati (Vulkan). Se la scheda video non supporta Vulkan:
`./DawnAndAsh.x86_64 --rendering-method gl_compatibility`.

## Avviare dal progetto (sviluppo)

Serve Godot 4.7 (`sudo pacman -S godot` su Arch/Omarchy).

```bash
./run.sh                 # avvia il gioco
./build.sh               # crea gli eseguibili Linux e Windows, l'installer .run e lo zip per Windows (scarica da solo i template al primo uso)
./build.sh windows       # solo Windows (oppure: ./build.sh linux)
./tools/fetch_assets.sh  # riscarica modelli, texture, suoni e musica (sono già nel repository)
```

---

## Modalità di gioco

- **Allenamento**: tu (Lega dell'Alba) contro le ondate di creep e le torri del Culto della Cenere, senza eroe nemico.
  Nel menu di pausa (**Esc**) ci sono le opzioni di allenamento: oro +1000, livello +1, azzera ricariche, invulnerabilità, velocità ×2.
- **1 contro 1 in rete**: uno **ospita**, l'altro **si unisce**. Entrambi usano Kael, con colori diversi.

## Controlli

| Input | Azione |
|---|---|
| **Click destro** a terra / su un nemico | muovi / attacca (tenendolo premuto continui a dare ordini) |
| **A** + click sinistro | attacco-movimento; su un tuo creep sotto il 50% di vita: **deny** |
| **S** | fermati |
| **Q W E R** | abilità: la prima pressione mostra gittata e area, **click sinistro** lancia, click destro/Esc annulla |
| **Ctrl + Q/W/E/R** (o il "+" sopra l'icona) | impara o potenzia un'abilità |
| **1–6** | usa un oggetto (pozioni) |
| **B** | negozio (si compra entro 18 m dalla tua fontana; click destro su un oggetto per venderlo) |
| **Frecce** o mouse ai bordi | scorri la telecamera · **rotella** zoom |
| **Spazio** (tenuto) | centra la telecamera su Kael · **Y** la blocca su di lui |
| **Minimappa** | click sinistro sposta la visuale, click destro muove Kael |
| **Tab** | tabella punteggio |
| **Esc / F10** | menu di pausa (in allenamento ferma il gioco) |
| **F12** | screenshot in `screenshots/` |
| **M** | musica sì/no |

### Le abilità di Kael
- **Q — Palla di fuoco**: sfera infuocata in linea retta che esplode sul primo nemico (danno ad area).
- **W — Scatto**: teletrasporto fino a 10 m.
- **E — Onda d'urto**: anello di fuoco attorno a Kael che danneggia e rallenta del 40%.
- **R — Meteora** (dal livello 6): dopo 1 secondo cade un cristallo infuocato, danno enorme e stordimento.

Le abilità non danneggiano gli edifici. La torre T2 è invulnerabile finché c'è la T1, l'Antico finché c'è la T2.
Prendi l'oro con i **last hit** (il colpo finale sui creep nemici).

---

## Giocare in due

### 1. Chi ospita (host)
1. Avvia il gioco → **Ospita partita** → **Avvia il server** (porta predefinita **7777**, UDP).
2. Il gioco mostra gli indirizzi IP della macchina: comunicane uno all'amico.
3. Quando l'amico entra nella lobby, premete entrambi **Pronto**: parte il conto alla rovescia.

### 2. Chi si unisce (client)
1. Avvia il gioco → **Unisciti a una partita** → inserisci IP e porta → **Connetti** → **Pronto**.
2. L'ultimo IP usato viene ricordato.

### Nella stessa rete (casa, LAN)
Usa l'IP locale dell'host: il gioco lo mostra nella schermata **Ospita partita**. Di solito funziona subito.

### Via internet
- **Consigliato: Tailscale** (o ZeroTier). Installatelo entrambi, entrate nella stessa rete Tailscale e usate l'IP
  Tailscale dell'host (inizia con `100.`). Non serve configurare il router.
  ```bash
  sudo pacman -S tailscale && sudo systemctl enable --now tailscaled && sudo tailscale up
  tailscale ip -4      # l'IP da comunicare all'amico
  ```
- **In alternativa: port forwarding** della porta **7777 UDP** sul router dell'host verso l'IP locale dell'host;
  l'amico userà l'IP pubblico dell'host.

### Firewall (solo se la connessione non parte)
Sulla macchina dell'host, se c'è un firewall attivo, apri la porta UDP 7777:
- ufw: `sudo ufw allow 7777/udp`
- firewalld: `sudo firewall-cmd --add-port=7777/udp --permanent && sudo firewall-cmd --reload`

### Cose da sapere
- Usate **la stessa versione** del gioco: con versioni diverse la connessione viene rifiutata con un messaggio chiaro.
- In alto a destra vedi **ping** e perdita di pacchetti (verde < 80 ms, giallo < 150 ms, rosso oltre).
- Se l'avversario si disconnette vinci **a tavolino**; se cade l'host, il client torna al menu.

---

## Impostazioni e prestazioni

Nel menu **Impostazioni**: qualità grafica (**Bassa / Media / Alta**), limite FPS, schermo intero, VSync,
lancio rapido delle abilità, scorrimento ai bordi, velocità della telecamera, volumi. Sono salvate in
`~/.local/share/dawn-and-ash/settings.cfg`.

- **Bassa**: per GPU integrate deboli (risoluzione 3D al 75%, niente glow, meno alberi).
- **Media** (predefinita): pensata per 60+ FPS su GPU integrate recenti.
- **Alta**: ombre di tutto, SSAO, MSAA, per GPU dedicate.

Misure reali in `benchmark_results.md`.

---

## Test automatici

```bash
godot --headless -- --autotest-training          # partita simulata con verifiche → AUTOTEST OK
./tools/net_tests.sh                             # rete con 0/80/150/250 ms di lag + chiusura improvvisa del client
godot -- --shots res://screenshots               # screenshot di controllo (menu, scontri, abilità, torre, negozio, vittoria, animazioni)
godot -- --benchmark                             # FPS per preset → benchmark_results.md
godot --headless -- --soak --soak-minutes 30     # partita lunga accelerata: memoria, nodi, creep incastrati
```

Simulatore di lag per prove manuali (lato client): `./run.sh --netsim latency=150,jitter=30,loss=3`.

## Modificare il bilanciamento

Tutti i numeri sono in **`scripts/autoload/Game.gd`**: statistiche di Kael (`HERO`), abilità (`ABILITIES`),
creep e ondate (`CREEPS`, `WAVE_*`), edifici (`BUILDINGS`), oggetti (`ITEMS`), oro ed esperienza.
Gli interruttori `ENABLE_*` attivano o disattivano le funzioni della Fase 2.

---

## Struttura del progetto

```
project.godot, scenes/main.tscn     progetto e scena principale
scripts/Main.gd                     menu ⇄ partita, flusso di rete
scripts/autoload/                   Game (costanti, impostazioni), Audio, Net (rete)
scripts/sim/                        simulazione autoritativa: Sim, Unit, HeroData, MapData
scripts/world/                      World (partita), UnitView (grafica unità), MapBuilder, CameraRig, shader
scripts/vfx/                        effetti visivi con pool
scripts/ui/                         HUD, overlay, minimappa, menu, fine partita
scripts/debug/AutoTest.gd           test automatici, screenshot, benchmark, soak
assets/                             modelli, texture, musica, suoni (+ CREDITS.md)
tools/                              script di download asset/template e test di rete
wiki/                               documentazione del progetto (wiki mantenuto dall'agente, apribile in Obsidian)
build/                              eseguibili esportati, installer .run e zip Windows (non nel repository: vedi le Release)
```

Documentazione tecnica dettagliata: `wiki/index.md`. Scelte prese durante lo sviluppo: `DECISIONS.md`.

---

## Autore

**Simone Silvetti** — [simonesilvetti.com](https://simonesilvetti.com) · identificativo dell'applicazione: `com.atomicgrove.dawnandash`.

## Licenza

Il codice è distribuito con licenza **GNU GPL v3.0 o successiva** (`GPL-3.0-or-later`): vedi il file `LICENSE`.
Copyright © 2026 Simone Silvetti. Gli asset di terze parti in `assets/` sono CC0 (vedi `assets/CREDITS.md`).

