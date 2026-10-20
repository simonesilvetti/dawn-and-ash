---
title: Architettura del software
type: system
tags: [architettura]
updated: 2026-10-20
sources: [scripts/]
---

# Architettura del software

```
scenes/main.tscn → scripts/Main.gd        menu ⇄ partita, flusso di rete, test automatici
autoload: Game.gd (costanti, impostazioni, input) · Audio.gd · Net.gd (ENet, lobby, RPC, netsim)
scripts/sim/      Sim.gd, Unit.gd, HeroData.gd, MapData.gd   ← logica pura, nessun nodo di scena
scripts/world/    World.gd, UnitView.gd, CameraRig.gd, MapBuilder.gd, shader
scripts/vfx/      Vfx.gd (pool di effetti), VfxLib.gd (particellari), shader
scripts/ui/       Hud.gd, Overlay.gd, Minimap.gd, AbilityButton.gd, MainMenu.gd, EndScreen.gd, UiKit.gd
scripts/debug/    AutoTest.gd
```

## Flusso
- **Server / allenamento**: `World` esegue `Sim.tick()` a 30 Hz; gli eventi (`sim.events`) vengono applicati localmente e inviati ai client; gli snapshot vengono costruiti per ogni client. → [[simulazione]], [[netcode]]
- **Client**: `World` riceve eventi (ritardati per allinearli all'interpolazione) e snapshot, interpola le unità e predice il proprio eroe.
- In allenamento si usa lo **stesso codice** del server (la rete non è un ramo a parte).
- La grafica (`UnitView`) legge i dati delle `Unit` e non contiene logica; un solo ciclo in `World._update_views` aggiorna tutte le viste.
