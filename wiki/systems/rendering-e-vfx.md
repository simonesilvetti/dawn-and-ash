---
title: Rendering ed effetti
type: system
tags: [grafica, vfx]
updated: 2026-10-21
sources: [scripts/world/UnitView.gd, scripts/vfx/Vfx.gd, scripts/vfx/VfxLib.gd, scripts/vfx/fire.gdshader, scripts/vfx/tail.gdshader, scripts/vfx/puff.gdshader, scripts/world/Terrain.gd, scripts/world/water.gdshader, scripts/world/Scenery.gd]
---

# Rendering ed effetti

## Unità (`UnitView`)
Modelli KayKit con mesh superflue nascoste, mantelli colorati per squadra, armi agganciate alle ossa (`BoneAttachment3D` su `handslot.r/l`), anello di squadra con ombra blob (`ring.gdshader`), lampo bianco quando vengono colpite (`material_overlay`), morte con animazione e affondamento. Edifici: cristallo emissivo rotante (più piccolo e meno saturo dalla v2), luce, scudo con bordo fresnel (`shield.gdshader`), crollo con macerie.
Nel guado del fiume le unità scendono all'altezza visiva del terreno (`Terrain.height`, solo grafica).

## Terreno, acqua, ambiente
- `Terrain.gd`: altezza visiva (argini e colline fuori dall'area percorribile, piano attorno alle basi, alveo del fiume con guado di 0.42 m nella corsia) e mesh a griglia 360 m con passo 1.5 m (calcolata una volta).
- `ground.gdshader`: 6 texture ambientCG (erba, sentiero, lastricato, roccia biplanare sui pendii, ciottoli, terra bruciata) con normal map; si campionano solo i livelli presenti nel pixel. Varianti per qualità con `#define` (`MapBuilder.shader_variant`).
- `water.gdshader`: rettangolo piatto a quota −0.16; il terreno più alto lo nasconde, così la riva nasce dal test di profondità. Colore secondo la profondità, schiuma, increspature da una NoiseTexture2D normal map. In Bassa e Media la profondità viene da una mappa del fondo 512×32 calcolata una volta (`Terrain.build_water`, ~2 ms di GPU risparmiati); in Alta dal depth buffer (schiuma anche attorno alle unità) con finte caustiche.
- Terreno (`Terrain.meshes()`) e alberi/rocce/montagne (`MapBuilder._build_foliage`) sono divisi in blocchi (60 m e 40 m) così la GPU scarta quelli fuori inquadratura.
- `Scenery.gd`: vegetazione minuta procedurale in MultiMesh a blocchi di 40 m (culling e distanza massima), mura ad anello attorno alle basi con varco verso la corsia, torri con catapulta, villaggio, oggetti di scena lungo la corsia, ponti in rovina, falò e bracieri con luce (tween infinito, niente script per nodo), braci nella metà del Culto.

## Effetti (`Vfx`)
Pool per proiettili, gruppi di particelle, anelli, colonne, muri di fiamme, meteore; **massimo 4 luci dinamiche** e **10 Decal** di bruciatura (riciclati, svaniscono). **Warmup** all'avvio per compilare gli shader.
- Proiettili: nucleo di fuoco animato (`fire.gdshader`) o luminoso, alone billboard, **coda continua** (`tail.gdshader`, quad orientato ogni frame lungo la direzione di volo e verso la telecamera), poche braci; la palla di fuoco porta una luce.
- Esplosioni a strati (`VfxLib.make_blast`): lampo, sbuffi di fuoco e fumo (`puff.gdshader`, dischi erosi dal rumore che si consumano con l'età), scintille; frammenti di roccia per meteora e crolli.
- Onda d'urto: muro di fiamme cilindrico che si allarga + anelli + polvere + bruciatura.
- Scintille sui colpi fisici visibili (massimo 12 contemporanee), polvere alla morte dei creep.
Scossa della telecamera (`Vfx.shake`), hit-stop in allenamento.

## Qualità (`World._apply_quality`, `MapBuilder`, `Scenery`)
| | Bassa | Media | Alta |
|---|---|---|---|
| Risoluzione 3D | 75% | 100% | 100% |
| Antialiasing | — | FXAA | MSAA 2× |
| Glow / SSAO | no / no | sì / no | sì / sì |
| Alberi | 35% | 70% | 100% |
| Texture del terreno | senza normal map | normal map | + anisotropico e anti-ripetizione |
| Erba, fiori, sassi | no | 30% | 100% (cespugli con ombre) |
| Falò, bracieri, braci, bruciature | fiamme senza luce, niente Decal | sì | sì |
| Ombre | eroi, edifici, mura | eroi, edifici, mura | anche creep, alberi, oggetti di scena; 4 split |
| Nuvole, particelle ambientali | no | sì | sì |
