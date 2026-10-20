---
title: Stile grafico
type: concept
tags: [grafica, arte]
updated: 2026-10-20
sources: [promt.md, scripts/world/MapBuilder.gd, scripts/world/ground.gdshader]
---

# Stile grafico

**3D low-poly cartoon**: colorato, leggibile, a metà tra Warcraft 3 e un Clash Royale in 3D. Visuale dall'alto inclinata di 50°.

- Modelli: solo **KayKit** (CC0) per coerenza → [[asset]].
- Luce calda di pomeriggio (sole inclinato, ombre), tonemap Filmic, glow, nebbia leggera, saturazione +12%.
- Terreno procedurale (`ground.gdshader`): erba che sfuma in cenere oltre il fiume, corsia di terra dal bordo irregolare, basi lastricate con anello di squadra, fiume con meandri animato, ombre delle nuvole.
- Vegetazione in MultiMesh che ondeggia al vento; montagne di confine su un bordo quadrato lontano dalle basi.
- Feedback: anelli di squadra con ombra "blob", barre della vita con scia, numeri del danno, indicatori di click, gittate e aree. → [[rendering-e-vfx]], [[interfaccia]]
