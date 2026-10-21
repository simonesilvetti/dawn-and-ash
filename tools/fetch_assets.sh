#!/usr/bin/env bash
# Scarica gli asset CC0 di KayKit (Kay Lousberg) usati dal gioco.
# Uso: ./tools/fetch_assets.sh   (idempotente: salta i file già presenti)
set -euo pipefail
cd "$(dirname "$0")/.."

RAW="https://raw.githubusercontent.com/KayKit-Game-Assets"
ADV="$RAW/KayKit-Character-Pack-Adventures-1.0/main/addons/kaykit_character_pack_adventures"
SKE="$RAW/KayKit-Character-Pack-Skeletons-1.0/main/addons/kaykit_character_pack_skeletons"
HEX="$RAW/KayKit-Medieval-Hexagon-Pack-1.0/main/addons/kaykit_medieval_hexagon_pack/Assets/gltf"

fetch() { # url dest
	local url="$1" dest="$2"
	[[ -s "$dest" ]] && return 0
	mkdir -p "$(dirname "$dest")"
	curl -fsSL --retry 3 -o "$dest" "$url"
	echo "  scaricato $dest"
}

echo "== Personaggi"
C=assets/models/chars
for f in Mage Knight Rogue_Hooded Barbarian; do fetch "$ADV/Characters/gltf/$f.glb" "$C/$f.glb"; done
for f in mage knight rogue barbarian; do fetch "$ADV/Characters/gltf/${f}_texture.png" "$C/${f}_texture.png"; done
for f in Skeleton_Warrior Skeleton_Minion Skeleton_Mage; do fetch "$SKE/Characters/gltf/$f.glb" "$C/$f.glb"; done
fetch "$SKE/Characters/gltf/skeleton_texture.png" "$C/skeleton_texture.png"
for f in Skeleton_Blade Skeleton_Staff Skeleton_Shield_Small_A; do
	fetch "$SKE/Assets/gltf/$f.gltf" "$C/$f.gltf"
	fetch "$SKE/Assets/gltf/$f.bin" "$C/$f.bin"
done

echo "== Ambiente"
E=assets/models/env
fetch "$HEX/decoration/nature/hexagons_medieval.png" "$E/hexagons_medieval.png"
gltf() { # subpath (senza estensione)
	local name; name="$(basename "$1")"
	fetch "$HEX/$1.gltf" "$E/$name.gltf"
	fetch "$HEX/$1.bin" "$E/$name.bin"
}
for t in green red; do
	for b in building_tower_A building_tower_B building_castle building_barracks building_archeryrange building_well building_tower_base; do
		gltf "buildings/$t/${b}_$t"
	done
	gltf "decoration/props/flag_$t"
done
for n in trees_A_large trees_A_medium trees_A_small trees_B_large trees_B_medium trees_B_small tree_single_A tree_single_B \
		tree_single_A_cut tree_single_B_cut rock_single_A rock_single_B rock_single_C rock_single_D rock_single_E \
		mountain_A_grass_trees mountain_B_grass_trees mountain_C_grass_trees hills_A_trees hills_B_trees hill_single_A \
		waterlily_A waterlily_B waterplant_A waterplant_B cloud_big cloud_small; do
	gltf "decoration/nature/$n"
done
for n in barrel crate_A_big crate_B_small tent weaponrack sack resource_stone; do gltf "decoration/props/$n"; done
for n in building_bridge_A building_bridge_B building_destroyed building_scaffolding building_grain fence_stone_straight \
		fence_wood_straight wall_straight wall_straight_gate wall_corner_A_outside; do gltf "buildings/neutral/$n"; done
# villaggi delle basi (Grafica v2)
for t in green red; do
	for b in blacksmith church home_A home_B market windmill lumbermill tavern tower_catapult; do gltf "buildings/$t/building_${b}_$t"; done
done
for n in bucket_arrows crate_long_A crate_open resource_lumber wheelbarrow pallet target crate_A_small crate_B_big; do gltf "decoration/props/$n"; done
for n in hills_A hills_B hill_single_B mountain_A_grass waterplant_C trees_A_cut trees_B_cut; do gltf "decoration/nature/$n"; done

echo "== Texture del terreno (ambientCG, CC0) -> solo Color e NormalGL a 1K"
T=assets/textures
acg() { # id nome
	[[ -s "$T/$2_albedo.jpg" ]] && return 0
	mkdir -p "$T"
	local tmp; tmp="$(mktemp -d)"
	curl -fsSL --retry 3 -o "$tmp/t.zip" "https://ambientcg.com/get?file=$1_1K-JPG.zip"
	unzip -qo "$tmp/t.zip" -d "$tmp/x"
	cp "$(find "$tmp/x" -name "*_Color.jpg" | head -1)" "$T/$2_albedo.jpg"
	cp "$(find "$tmp/x" -name "*_NormalGL.jpg" | head -1)" "$T/$2_normal.jpg"
	rm -rf "$tmp"
	echo "  scaricato $T/$2 ($1)"
}
acg Grass004 grass
acg Ground081 dirt
acg PavingStones070 paving
acg Rock051 rock
acg Ground103 soil
acg Gravel041 pebbles

echo "== Musica (OpenGameArt, CC0) -> ogg"
M=assets/music
OGA="https://opengameart.org/sites/default/files"
music() { # url nome
	[[ -s "$M/$2.ogg" ]] && return 0
	mkdir -p "$M"
	local tmp; tmp="$(mktemp --suffix=."${1##*.}")"
	curl -fsSL --retry 3 -o "$tmp" "$1"
	ffmpeg -loglevel error -y -i "$tmp" -ac 2 -ar 44100 -c:a libvorbis -q:a 4 "$M/$2.ogg"
	rm -f "$tmp"
	echo "  convertito $M/$2.ogg"
}
music "$OGA/the_ancient_legend_1.mp3" menu        # "The Ancient Legend" - vitalezzz
music "$OGA/TownTheme.mp3" calm                   # "Town Theme RPG" - cynicmusic
music "$OGA/battleThemeA.mp3" battle              # "Battle Theme A" - cynicmusic
music "$OGA/victory.mp3" victory                  # "Medieval: Victory Theme" - RandomMind
music "$OGA/defeat.mp3" defeat                    # "Medieval: Defeat Theme" - RandomMind

echo "== Effetti sonori (Kenney, CC0)"
K="$(mktemp -d)"
trap 'rm -rf "$K"' EXIT
kenney() { # url
	curl -fsSL --retry 3 -o "$K/p.zip" "$1" && unzip -qo "$K/p.zip" -d "$K/x" && rm "$K/p.zip"
}
if [[ ! -s assets/sounds/coins.ogg ]]; then
	kenney "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip"
	kenney "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"
	kenney "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip"
	kenney "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip"
	kenney "https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip"
	mkdir -p assets/sounds
	sfx() { # nome_destinazione file_sorgente
		local src; src="$(find "$K/x" -name "$2" | head -1)"
		[[ -n "$src" ]] && cp "$src" "assets/sounds/$1.ogg" || echo "  MANCA $2"
	}
	sfx hit_melee_1 impactPlate_medium_000.ogg; sfx hit_melee_2 impactPlate_medium_001.ogg; sfx hit_melee_3 impactPlate_medium_002.ogg
	sfx hit_punch_1 impactPunch_medium_000.ogg; sfx hit_punch_2 impactPunch_medium_001.ogg
	sfx bolt_cast_1 laserSmall_000.ogg; sfx bolt_cast_2 laserSmall_001.ogg
	sfx bolt_hit_1 impactSoft_medium_000.ogg; sfx bolt_hit_2 impactSoft_medium_001.ogg
	sfx tower_shot laserLarge_000.ogg; sfx tower_hit impactMetal_000.ogg
	sfx fireball_cast thrusterFire_000.ogg; sfx explosion_1 explosionCrunch_000.ogg; sfx explosion_2 explosionCrunch_001.ogg
	sfx blink forceField_000.ogg; sfx shockwave lowFrequency_explosion_000.ogg; sfx big_explosion lowFrequency_explosion_001.ogg
	sfx bones_1 impactWood_light_000.ogg; sfx bones_2 impactWood_light_001.ogg; sfx bones_3 impactWood_light_002.ogg
	sfx death_soft impactSoft_heavy_000.ogg; sfx collapse impactWood_heavy_000.ogg
	sfx coins handleCoins.ogg; sfx coins_2 handleCoins2.ogg; sfx buy metalLatch.ogg
	sfx ui_click click_001.ogg; sfx ui_hover tick_001.ogg; sfx ui_open open_001.ogg; sfx ui_close close_001.ogg
	sfx ui_error error_004.ogg; sfx ui_confirm confirmation_001.ogg; sfx move_click select_001.ogg
	sfx level_up jingles_PIZZI00.ogg; sfx respawn jingles_STEEL04.ogg; sfx alert jingles_HIT00.ogg
fi

echo "Fatto."
