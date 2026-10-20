---
title: Rendering ed effetti
type: system
tags: [grafica, vfx]
updated: 2026-10-20
sources: [scripts/world/UnitView.gd, scripts/vfx/Vfx.gd, scripts/vfx/VfxLib.gd]
---

# Rendering ed effetti

## Unità (`UnitView`)
Modelli KayKit con mesh superflue nascoste, mantelli colorati per squadra, armi agganciate alle ossa (`BoneAttachment3D` su `handslot.r/l`), anello di squadra con ombra blob (`ring.gdshader`), lampo bianco quando vengono colpite (`material_overlay`), morte con animazione e affondamento. Edifici: cristallo emissivo rotante, luce, scudo con bordo fresnel (`shield.gdshader`), crollo con macerie.

## Effetti (`Vfx`)
Pool per proiettili, particellari, anelli, colonne, meteore e **massimo 4 luci dinamiche** contemporanee. **Warmup** all'avvio: ogni effetto compare una volta fuori vista per compilare gli shader. Scossa della telecamera (`Vfx.shake`), hit-stop in allenamento.

## Qualità (`World._apply_quality`, `MapBuilder`)
| | Bassa | Media | Alta |
|---|---|---|---|
| Risoluzione 3D | 75% | 100% | 100% |
| Antialiasing | — | FXAA | MSAA 2× |
| Glow / SSAO | no / no | sì / no | sì / sì |
| Vegetazione | 35% | 70% | 100% |
| Ombre | eroi, edifici | eroi, edifici | anche creep e alberi, 4 split |
| Nuvole, particelle ambientali | no | sì | sì |
