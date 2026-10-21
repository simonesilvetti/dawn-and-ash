---
title: Rendering ed effetti
type: system
tags: [grafica, vfx]
updated: 2026-10-22
sources: [scripts/world/MapBuilder.gd, scripts/world/foliage.gdshader, scripts/world/grass.gdshader, scripts/world/wake.gdshader, scripts/world/ground.gdshader, scripts/world/UnitView.gd, scripts/vfx/Vfx.gd, scripts/vfx/VfxLib.gd, scripts/vfx/fire.gdshader, scripts/vfx/tail.gdshader, scripts/vfx/puff.gdshader, scripts/world/Terrain.gd, scripts/world/water.gdshader, scripts/world/Scenery.gd]
---

# Rendering ed effetti

## Unità (`UnitView`)
Modelli KayKit con mesh superflue nascoste, mantelli colorati per squadra, armi agganciate alle ossa (`BoneAttachment3D` su `handslot.r/l`), anello di squadra con ombra blob (`ring.gdshader`), lampo bianco quando vengono colpite (`material_overlay`), morte con animazione e affondamento. Edifici: cristallo emissivo rotante a gemma (bipiramide esagonale con bordo luminoso, dal 2026-10-21 sera; prima era un prisma triangolare), luce, scudo con bordo fresnel (`shield.gdshader`), crollo con macerie.
Nel guado del fiume le unità scendono all'altezza visiva del terreno (`Terrain.height`, solo grafica) e mostrano
**increspature** sul pelo dell'acqua (`UnitView._update_wake`, `wake.gdshader`: due anelli che si allargano e schiuma
attorno alle gambe; un quad per unità immersa, creato alla prima immersione, intensità per istanza più forte in movimento).

## Terreno, acqua, ambiente
- `Terrain.gd`: altezza visiva (argini e colline fuori dall'area percorribile, piano attorno alle basi, alveo del fiume con guado di 0.42 m nella corsia) e mesh a griglia 360 m con passo 1.5 m (calcolata una volta).
- `ground.gdshader`: 6 texture ambientCG (erba, sentiero, lastricato, roccia biplanare sui pendii, ciottoli, terra bruciata) con normal map; si campionano solo i livelli presenti nel pixel. Varianti per qualità con `#define` (`MapBuilder.shader_variant`).
  Sentiero: da Media un secondo campione ruotato e a scala diversa toglie le righe della ripetizione; tracce consumate
  parallele alla corsia. Lastricato delle basi con chiazze di terra battuta e muschio (fuliggine nel Culto) verso il bordo.
  Ciottoli sommersi tinti verde-acqua.
- **Occlusione finta** (`MapBuilder.add_occluder`, uniforme globale `occ_tex` dichiarata in `project.godot`
  `[shader_globals]`): mappa 256×256 sui 360 m del terreno, scurita sotto alberi, rocce, edifici del villaggio, torri e
  Antichi; le macchie sono spostate nella direzione opposta al sole (`SHADOW_DIR`) e fanno da ombre finte degli alberi,
  che in Bassa/Media non proiettano ombre. La leggono `ground.gdshader` (fino a −70%) e `grass.gdshader` (nel vertex).
  Costo: una lettura di texture. Ricostruita a ogni partita (dipende dalla densità degli alberi del preset).
- Alberi (`foliage.gdshader`): tinta e luminosità diverse per albero (hash della posizione dell'istanza, `vary`) verso
  verdi più profondi o più gialli dell'atlante KayKit, e base più scura (`base_ao`, metri). Rocce e montagne con
  variazione ridotta; `MapBuilder.static_material(..., vary)` la attiva solo per oggetti fermi.
- `water.gdshader`: rettangolo piatto a quota −0.16; il terreno più alto lo nasconde, così la riva nasce dal test di profondità. Colore secondo la profondità (acqua bassa quasi trasparente, alfa 0.2), schiuma a due fasce (linea piena + fascia spezzata), increspature da una NoiseTexture2D normal map, **scie della corrente** (rumore stirato lungo il fiume) e **scintillii** (riflesso speculare finto con una direzione "artistica" `glint_dir` davanti alla telecamera, perché il sole vero è alle sue spalle). In Bassa e Media la profondità viene da una mappa del fondo 512×32 calcolata una volta (`Terrain.build_water`, ~2 ms di GPU risparmiati); in Alta dal depth buffer (schiuma anche attorno alle unità) con finte caustiche.
- Terreno (`Terrain.meshes()`) e alberi/rocce/montagne (`MapBuilder._build_foliage`) sono divisi in blocchi (60 m e 40 m) così la GPU scarta quelli fuori inquadratura.
- `Scenery.gd`: vegetazione minuta procedurale in MultiMesh a blocchi di 40 m (culling e distanza massima), mura ad anello attorno alle basi con varco verso la corsia, torri con catapulta, villaggio, oggetti di scena lungo la corsia, ponti in rovina, falò e bracieri con luce (tween infinito, niente script per nodo), braci nella metà del Culto.

## Luce e colore (`MapBuilder._build_environment`)
Tonemapper Filmic (esposizione 1.08), saturazione 1.14, contrasto 1.1; sole caldo (energia 1.35), luce ambiente più
fredda e bassa (0.68) per ombre più profonde. Provati AgX e ACES (2026-10-21 notte): immagine più slavata, scartati.

## Effetti (`Vfx`)
Pool per proiettili, gruppi di particelle, anelli, colonne, muri di fiamme, meteore; **massimo 4 luci dinamiche** e **10 Decal** di bruciatura (riciclati, svaniscono). **Warmup** all'avvio per compilare gli shader.
- Proiettili: nucleo di fuoco animato (`fire.gdshader`) o luminoso, alone billboard, **coda continua** (`tail.gdshader`, quad orientato ogni frame lungo la direzione di volo e verso la telecamera), poche braci; la palla di fuoco porta una luce.
- Esplosioni a strati (`VfxLib.make_blast`): lampo, sbuffi di fuoco e fumo (`puff.gdshader`, dischi erosi dal rumore che si consumano con l'età), scintille; frammenti di roccia per meteora e crolli.
- Onda d'urto: muro di fiamme cilindrico che si allarga + anelli + polvere + bruciatura. Il muro (`fire.gdshader`, `wall=1`) usa l'altezza del vertice (non le UV del cilindro): base piena e lingue di fuoco frastagliate verso l'alto, visibile anche il lato interno.
- Esplosioni grandi (meteora, crolli): intensità del lampo e delle fiamme divisa per `scala^1.2` e colore iniziale arancio invece che bianco, perché molte particelle additive sovrapposte saturavano al bianco. Provate anche fiamme opache: sembravano polvere color crema, scartate.
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
