class_name UnitView
extends Node3D
## Rappresentazione visiva di una Unit: modello animato KayKit, anello di squadra, effetti di colpo e morte.
## Aggiornata da World (nessun _process per nodo, per prestazioni). Riutilizzata tramite pool.

const CHARS := "res://assets/models/chars/"
const ENV := "res://assets/models/env/"

# Configurazione dei modelli per (tipo, squadra)
const MODELS := {
	# eroi: "casts" = [animazione, velocità] per Q, W, E, R
	"hero_kael": {"file": "Mage.glb", "scale": 0.95,
		"hide": ["Spellbook", "Spellbook_open", "1H_Wand", "Mage_Hat"],
		"idle": "Idle", "move": "Running_A", "attack": "Spellcast_Shoot", "cast": "Spellcast_Long",
		"casts": [["Spellcast_Shoot", 1.6], ["Spellcast_Shoot", 1.6], ["Spellcast_Raise", 1.6], ["Spellcast_Long", 1.2]],
		"death": "Death_A", "hit": "Hit_A", "run_ref": 5.5, "impact": 0.45},
	"hero_peppino": {"file": "Knight.glb", "scale": 0.98,
		"hide": ["2H_Sword", "Round_Shield", "Rectangle_Shield", "Spike_Shield", "1H_Sword_Offhand"],
		"idle": "Idle", "move": "Running_A", "attack": "1H_Melee_Attack_Slice_Diagonal", "cast": "2H_Melee_Attack_Spin",
		"casts": [["2H_Melee_Attack_Spin", 1.5], ["1H_Melee_Attack_Stab", 1.2], ["Block", 1.0], ["2H_Melee_Attack_Chop", 1.1]],
		"death": "Death_A", "hit": "Hit_A", "run_ref": 5.5, "impact": 0.42},
	"hero_gorm": {"file": "Barbarian.glb", "scale": 1.06,
		"hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug"],
		"idle": "2H_Melee_Idle", "move": "Running_A", "attack": "2H_Melee_Attack_Slice", "cast": "2H_Melee_Attack_Chop",
		# il colpo a terra della clip Chop è al 57%: velocità scelte perché coincida con il cast point
		"casts": [["2H_Melee_Attack_Chop", 1.86], ["2H_Melee_Attack_Chop", 3.0], ["", 1.0], ["", 1.0]],
		"leap": "Jump_Full_Short", "death": "Death_B", "hit": "Hit_A", "run_ref": 5.5, "impact": 0.55},
	"melee_0": {"file": "Knight.glb", "scale": 0.66,
		"hide": ["2H_Sword", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "1H_Sword_Offhand"],
		"idle": "Idle", "move": "Running_B", "attack": "1H_Melee_Attack_Chop", "death": "Death_A",
		"run_ref": 4.6, "impact": 0.45},
	"ranged_0": {"file": "Rogue_Hooded.glb", "scale": 0.66,
		"hide": ["Knife_Offhand", "1H_Crossbow", "Knife", "Throwable"],
		"idle": "2H_Ranged_Aiming", "move": "Running_B", "attack": "2H_Ranged_Shoot", "death": "Death_B",
		"run_ref": 4.6, "impact": 0.3},
	"melee_1": {"file": "Skeleton_Warrior.glb", "scale": 0.66, "hide": [],
		"weapon_r": "Skeleton_Blade.gltf", "weapon_l": "Skeleton_Shield_Small_A.gltf",
		"idle": "Idle_Combat", "move": "Running_C", "attack": "1H_Melee_Attack_Slice_Diagonal",
		"death": "Death_C_Skeletons", "spawn": "Spawn_Ground_Skeletons", "run_ref": 4.6, "impact": 0.45},
	"siege_0": {"file": "Barbarian.glb", "scale": 0.86,
		"hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug"],
		"idle": "Idle", "move": "Walking_A", "attack": "Throw", "death": "Death_A",
		"run_ref": 3.0, "impact": 0.5},
	"siege_1": {"file": "Skeleton_Minion.glb", "scale": 0.92, "hide": [],
		"idle": "Idle_Combat", "move": "Walking_D_Skeletons", "attack": "Throw", "death": "Death_C_Skeletons",
		"spawn": "Spawn_Ground_Skeletons", "run_ref": 3.0, "impact": 0.5},
	"ranged_1": {"file": "Skeleton_Mage.glb", "scale": 0.66, "hide": [],
		"weapon_r": "Skeleton_Staff.gltf",
		"idle": "Idle", "move": "Running_A", "attack": "Spellcast_Shoot", "death": "Death_C_Skeletons",
		"spawn": "Spawn_Ground_Skeletons", "run_ref": 4.6, "impact": 0.45},
}

const STAFF_TIP_Y := 1.12           # cristallo in cima al bastone di Kael (coordinate locali della mesh)

static var _ring_mats: Dictionary = {}
static var _flash_mat: StandardMaterial3D
static var _ring_mesh: QuadMesh
static var _tint_cache: Dictionary = {}
static var _anim_configured: Dictionary = {}

var unit_id: int = 0
var kind: int = 0
var team: int = 0
var model_key: String = ""
var model: Node3D
var anim: AnimationPlayer
var cfg: Dictionary = {}
var ring: MeshInstance3D
var meshes: Array[MeshInstance3D] = []
var height: float = 2.0             # altezza della barra della vita
var bar_width: float = 40.0
var dead := false
var death_t: float = 0.0
var flash_t: float = 0.0
var cur_anim := ""
var lock_t: float = 0.0             # durata residua di un'animazione "one shot" (attacco/lancio)
var facing: float = 0.0
var vis_pos := Vector3.ZERO
var wake: MeshInstance3D            # increspature nell'acqua del guado (creata alla prima immersione)
static var _wake_mat: ShaderMaterial
var crystal: Node3D                 # cristallo luminoso degli edifici
var light: OmniLight3D
var shield: MeshInstance3D          # scudo trasparente degli edifici invulnerabili
var buff_shield: MeshInstance3D     # bolla dorata dello Scudo di ferro (Peppino)
var totem_rune: MeshInstance3D      # fascia di rune del totem di Gorm (si accende col Totem del sisma)
var totem_fire: GPUParticles3D      # braci sulla testa del totem carico
var totem_light: OmniLight3D
var empowered := false
var stun_fx: Node3D                 # stelline che girano sopra la testa degli storditi
var hop_t: float = -1.0             # balzo in corso (Totem di Gorm): tempo trascorso, durata, altezza
var hop_dur: float = 0.5
var hop_h: float = 2.0
var building_model: Node3D
var collapse_t: float = -1.0
var rubble: Node3D
var hover := false
var anim_accum: float = 0.0
var anim_phase: int = 0             # sfasa gli aggiornamenti tra i creep


static func make_key(k: int, t: int, subtype: String = "") -> String:
	match k:
		Game.Kind.HERO: return "hero_" + (subtype if Game.HEROES.has(subtype) else "kael")
		Game.Kind.CREEP_MELEE: return "melee_%d" % t
		Game.Kind.CREEP_RANGED: return "ranged_%d" % t
		Game.Kind.CREEP_SIEGE: return "siege_%d" % t
	return "building"


## Mette la vista "a riposo" nel pool: invisibile e senza elaborazione (niente animazioni).
func park() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func setup(u_id: int, k: int, t: int, subtype: String, quality: int) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	unit_id = u_id
	anim_phase = u_id % 2
	kind = k
	team = t
	dead = false
	death_t = 0.0
	collapse_t = -1.0
	visible = true
	if model == null and building_model == null:
		model_key = make_key(k, t, subtype)
		if model_key == "building":
			_build_building(subtype, quality)
		else:
			_build_character(quality)
	if ring == null:
		_build_ring()
	_reset_visual()


func _reset_visual() -> void:
	if model:
		model.position = Vector3.ZERO
		model.rotation = Vector3.ZERO
	if ring:
		ring.visible = true
	cur_anim = ""
	lock_t = 0.0
	flash_t = 0.0
	hop_t = -1.0
	_set_flash(false)
	_set_empowered(false)
	if stun_fx:
		stun_fx.visible = false
	if anim:
		play(cfg.get("idle", "Idle"), 0.0)


func _build_character(quality: int) -> void:
	cfg = MODELS[model_key]
	var ps: PackedScene = load(CHARS + cfg.file)
	model = ps.instantiate()
	model.scale = Vector3.ONE * cfg.scale
	add_child(model)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name in cfg.hide:
			mi.visible = false
			continue
		meshes.append(mi)
		# Ombre reali solo per gli eroi (o tutti in qualità alta); i creep usano l'ombra "blob" dell'anello
		var shadows := kind == Game.Kind.HERO or quality >= 2
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Armi per gli scheletri (agganciate all'osso della mano)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel:
		for side in ["r", "l"]:
			var wf: String = cfg.get("weapon_" + side, "")
			if wf == "":
				continue
			var ba := BoneAttachment3D.new()
			ba.bone_name = "handslot." + side
			skel.add_child(ba)
			var w: Node3D = (load(CHARS + wf) as PackedScene).instantiate()
			ba.add_child(w)
			for m in w.find_children("*", "MeshInstance3D", true, false):
				meshes.append(m)
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		# i creep avanzano l'animazione a mano (30 Hz, sospesa fuori schermo): meno CPU
		if kind != Game.Kind.HERO:
			anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_configure_animations(anim, cfg)
		anim.playback_default_blend_time = 0.15
	height = 2.3 if kind == Game.Kind.HERO else (2.4 if kind == Game.Kind.CREEP_SIEGE else 1.8)
	bar_width = 70.0 if kind == Game.Kind.HERO else (50.0 if kind == Game.Kind.CREEP_SIEGE else 38.0)
	_add_rim_light()
	# mantelli nel colore della squadra; Kael ha anche la fiamma sul bastone
	_tint_capes()
	if model_key == "hero_kael":
		_add_staff_flame(skel)
	elif model_key == "hero_peppino":
		_dress_warrior()
	elif model_key == "hero_gorm":
		_dress_shaker()


## Imposta i loop delle clip una sola volta per modello: modificare un'Animation condivisa
## durante la partita costringe tutti gli AnimationPlayer a ricostruire le cache (scatti).
static func _configure_animations(ap: AnimationPlayer, c: Dictionary) -> void:
	if _anim_configured.has(c.file):
		return
	_anim_configured[c.file] = true
	for a in [c.idle, c.move]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var once: Array = []
	for key in ["death", "attack", "spawn", "cast", "leap"]:
		once.append(c.get(key, ""))
	for cs in c.get("casts", []):
		once.append(cs[0])
	for a in once:
		if a != "" and ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_NONE


## Leggera luce di contorno sui materiali dei personaggi (una volta per materiale condiviso):
## le unità si staccano meglio dal terreno con texture.
func _add_rim_light() -> void:
	for mi in meshes:
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m and not m.rim_enabled:
				m.rim_enabled = true
				m.rim = 0.45
				m.rim_tint = 0.35


func _tint_capes() -> void:
	var col: Color
	if kind == Game.Kind.HERO:
		col = Color(0.95, 0.35, 0.18) if team == 0 else Color(0.5, 0.22, 0.72)
	else:
		col = Color(0.25, 0.75, 0.7) if team == 0 else Color(0.7, 0.2, 0.4)
	for mi in meshes:
		var n := String(mi.name)
		if not (n.ends_with("_Cape") or n.ends_with("_Cloak")):
			continue
		var key := "%s_%d_%d" % [n, team, kind]
		var mat: StandardMaterial3D = _tint_cache.get(key)
		if mat == null:
			var base := mi.get_active_material(0)
			mat = (base.duplicate() if base else StandardMaterial3D.new()) as StandardMaterial3D
			mat.albedo_color = col
			_tint_cache[key] = mat
		mi.material_override = mat


## Peppino: elmo dorato (violaceo per il Culto) che lo distingue dai cavalieri dei creep, scudo a goccia lucido.
func _dress_warrior() -> void:
	var helm: MeshInstance3D = model.find_child("Knight_Helmet", true, false)
	if helm and helm.mesh:
		var hkey := "pep_helm_%d" % team
		var hm: StandardMaterial3D = _tint_cache.get(hkey)
		if hm == null:
			var hb := helm.get_active_material(0) as StandardMaterial3D
			hm = (hb.duplicate() if hb else StandardMaterial3D.new()) as StandardMaterial3D
			hm.albedo_color = Color(1.0, 0.82, 0.45) if team == 0 else Color(0.78, 0.62, 0.98)
			hm.metallic = 0.55
			hm.roughness = 0.35
			_tint_cache[hkey] = hm
		helm.material_override = hm
	var sh: MeshInstance3D = model.find_child("Badge_Shield", true, false)
	if sh and sh.mesh:
		var key2 := "pep_shield_%d" % team
		var m2: StandardMaterial3D = _tint_cache.get(key2)
		if m2 == null:
			var base2 := sh.get_active_material(0) as StandardMaterial3D
			m2 = (base2.duplicate() if base2 else StandardMaterial3D.new()) as StandardMaterial3D
			m2.metallic = 0.5
			m2.roughness = 0.35
			m2.rim_enabled = true
			m2.rim = 0.6
			m2.rim_tint = 0.5
			_tint_cache[key2] = m2
		sh.material_override = m2


## Gorm: totem di pietra a due mani (manico di legno, testa di roccia con una fascia di rune) al posto dell'ascia.
## Mesh primitive condivise tra le istanze; la fascia di rune è emissiva e si accende col Totem del sisma.
static var _totem_parts: Dictionary = {}

func _dress_shaker() -> void:
	var hand: Node3D = model.find_child("handslot_r", true, false)
	if hand == null:
		return
	var rune_col := Color(1.0, 0.55, 0.15) if team == 0 else Color(0.72, 0.35, 1.0)
	if _totem_parts.is_empty():
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.06
		shaft.bottom_radius = 0.075
		shaft.height = 1.45
		shaft.radial_segments = 8
		shaft.rings = 1
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.42, 0.27, 0.15)
		wood.roughness = 0.85
		shaft.material = wood
		_totem_parts.shaft = shaft
		var head := CylinderMesh.new()       # testa: prisma ottagonale tozzo, un po' rastremato
		head.top_radius = 0.25
		head.bottom_radius = 0.31
		head.height = 0.72
		head.radial_segments = 8
		head.rings = 1
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.5, 0.46, 0.42)
		stone.roughness = 0.9
		stone.rim_enabled = true
		stone.rim = 0.4
		stone.rim_tint = 0.3
		head.material = stone
		_totem_parts.head = head
		var cap := CylinderMesh.new()        # punta: tronco di cono di pietra più chiara
		cap.top_radius = 0.09
		cap.bottom_radius = 0.25
		cap.height = 0.24
		cap.radial_segments = 8
		cap.rings = 1
		var stone2 := stone.duplicate() as StandardMaterial3D
		stone2.albedo_color = Color(0.62, 0.58, 0.52)
		cap.material = stone2
		_totem_parts.cap = cap
		var band := CylinderMesh.new()       # legature di cuoio sul manico
		band.top_radius = 0.085
		band.bottom_radius = 0.085
		band.height = 0.07
		band.radial_segments = 8
		band.rings = 1
		var leather := StandardMaterial3D.new()
		leather.albedo_color = Color(0.25, 0.14, 0.08)
		band.material = leather
		_totem_parts.band = band
		var rune := CylinderMesh.new()       # fascia di rune attorno alla testa
		rune.top_radius = 0.3
		rune.bottom_radius = 0.315
		rune.height = 0.12
		rune.radial_segments = 8
		rune.rings = 1
		rune.cap_top = false
		rune.cap_bottom = false
		_totem_parts.rune = rune
	var root := Node3D.new()
	root.name = "Totem"
	hand.add_child(root)
	var parts := [["shaft", Vector3(0, 0.38, 0)], ["head", Vector3(0, 1.38, 0)], ["cap", Vector3(0, 1.86, 0)],
		["band", Vector3(0, 0.0, 0)], ["band", Vector3(0, 0.95, 0)]]
	for pd in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _totem_parts[pd[0]]
		mi.position = pd[1]
		root.add_child(mi)
		meshes.append(mi)
	totem_rune = MeshInstance3D.new()
	totem_rune.mesh = _totem_parts.rune
	totem_rune.position = Vector3(0, 1.3, 0)
	totem_rune.material_override = VfxLib.glow_material(rune_col, 1.2)
	totem_rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(totem_rune)
	totem_fire = VfxLib.make_flame(rune_col)
	totem_fire.position = Vector3(0, 1.5, 0)
	totem_fire.emitting = false
	totem_fire.visible = false
	root.add_child(totem_fire)
	totem_light = OmniLight3D.new()
	totem_light.light_color = rune_col
	totem_light.light_energy = 1.3
	totem_light.omni_range = 4.5
	totem_light.shadow_enabled = false
	totem_light.position = Vector3(0, 1.35, 0)
	totem_light.visible = false
	root.add_child(totem_light)
	for mi in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _set_empowered(on: bool) -> void:
	if on == empowered or totem_rune == null:
		return
	empowered = on
	var rune_col := Color(1.0, 0.55, 0.15) if team == 0 else Color(0.72, 0.35, 1.0)
	totem_rune.material_override = VfxLib.glow_material(rune_col, 3.2 if on else 1.2)
	totem_fire.visible = on
	totem_fire.emitting = on
	totem_light.visible = on


## Balzo (Totem di Gorm): il modello segue un arco sopra la posizione a terra, che arriva dalla simulazione.
func leap(dur: float, h: float) -> void:
	hop_t = 0.0
	hop_dur = maxf(dur, 0.1)
	hop_h = h
	var a: String = cfg.get("leap", "")
	if anim and a != "" and anim.has_animation(a):
		# la clip comprende stacco, volo e atterraggio: la si adatta alla durata del balzo
		var length := anim.get_animation(a).length
		var speed := length / (hop_dur + 0.35)
		cur_anim = ""
		play(a, 0.05, speed)
		lock_t = hop_dur + 0.1


func _update_hop(delta: float) -> void:
	hop_t += delta
	var k := clampf(hop_t / hop_dur, 0.0, 1.0)
	model.position.y = hop_h * 4.0 * k * (1.0 - k)
	if k >= 1.0:
		hop_t = -1.0
		model.position.y = 0.0


## Stelline dello stordimento: tre punti luminosi che girano sopra la testa (create alla prima occorrenza).
static var _star_mesh: QuadMesh

func _update_stun_fx(delta: float, on: bool) -> void:
	if stun_fx == null:
		if not on:
			return
		if _star_mesh == null:
			_star_mesh = QuadMesh.new()
			_star_mesh.size = Vector2(0.32, 0.32)
			_star_mesh.material = VfxLib.halo_material(Color(1.0, 0.9, 0.45))
		stun_fx = Node3D.new()
		for i in 3:
			var st := MeshInstance3D.new()
			st.mesh = _star_mesh
			st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var ang := TAU * i / 3.0
			st.position = Vector3(cos(ang) * 0.42, 0.0, sin(ang) * 0.42)
			stun_fx.add_child(st)
		stun_fx.position.y = height - 0.05
		add_child(stun_fx)
	stun_fx.visible = on
	if on:
		stun_fx.rotation.y += delta * 5.0
		stun_fx.position.y = height - 0.05 + sin(Time.get_ticks_msec() * 0.006) * 0.05


func _add_staff_flame(_skel: Skeleton3D) -> void:
	# la fiamma è figlia del bastone, sull'estremità con il cristallo
	var staff: Node3D = model.find_child("2H_Staff", true, false)
	if staff == null:
		return
	var tip := Vector3(0, STAFF_TIP_Y, 0)
	var fire_col := Color(1.0, 0.55, 0.15) if team == 0 else Color(0.7, 0.3, 1.0)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 12
	sm.rings = 6
	orb.mesh = sm
	orb.material_override = VfxLib.glow_material(fire_col, 3.0)
	orb.position = tip
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staff.add_child(orb)
	var p := VfxLib.make_flame(fire_col)
	p.position = tip
	staff.add_child(p)
	light = OmniLight3D.new()
	light.light_color = fire_col
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = tip
	staff.add_child(light)


func _build_building(subtype: String, quality: int) -> void:
	var col := "green" if team == 0 else "red"
	var file := ""
	var s := 4.0
	match subtype:
		"t1": file = "building_tower_A_%s.gltf" % col; s = 3.6; height = 8.6; bar_width = 90.0
		"t2": file = "building_tower_B_%s.gltf" % col; s = 3.6; height = 9.6; bar_width = 90.0
		"ancient": file = "building_castle_%s.gltf" % col; s = 3.0; height = 13.0; bar_width = 140.0
		"fountain": file = "building_well_%s.gltf" % col; s = 4.5; height = 4.5; bar_width = 0.0
	building_model = (load(ENV + file) as PackedScene).instantiate()
	building_model.scale = Vector3.ONE * s
	building_model.rotation.y = -MapData.team_dir(team).angle() + PI * 0.5
	add_child(building_model)
	for m in building_model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
	var glow_col: Color = Game.TEAM_COLORS[team]
	# Cristallo fluttuante sopra torri e Antico
	if subtype != "fountain":
		crystal = Node3D.new()
		# gemma a bipiramide esagonale: punta alta e slanciata sopra, corta sotto
		var big := subtype == "ancient"
		var k := 1.9 if big else 1.0
		for part in 2:
			var cm := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = 0.36 * k
			cyl.height = (0.95 if part == 0 else 0.45) * k
			cyl.radial_segments = 6
			cyl.rings = 1
			cyl.cap_bottom = false
			cm.mesh = cyl
			cm.material_override = crystal_material(team)
			cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if part == 0:
				cm.position.y = cyl.height * 0.5
			else:
				cm.rotation_degrees.x = 180.0
				cm.position.y = -cyl.height * 0.5
			crystal.add_child(cm)
		crystal.position.y = height - (0.4 if not big else -1.0)
		add_child(crystal)
		if quality >= 1 or big:
			light = OmniLight3D.new()
			light.light_color = glow_col
			light.light_energy = 2.0 if big else 1.2
			light.omni_range = 14.0 if big else 8.0
			light.position = crystal.position
			add_child(light)
	else:
		var p := VfxLib.make_fountain(glow_col)
		p.position.y = 2.0
		add_child(p)
		light = OmniLight3D.new()
		light.light_color = glow_col
		light.light_energy = 2.0
		light.omni_range = 12.0
		light.position.y = 3.0
		add_child(light)
	# Scudo semitrasparente per gli edifici invulnerabili
	if subtype == "t2" or subtype == "ancient":
		shield = MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := 4.0 if subtype == "t2" else 7.5
		sm.radius = r
		sm.height = r * 2.0
		shield.mesh = sm
		var smat := ShaderMaterial.new()
		smat.shader = load("res://scripts/vfx/shield.gdshader")
		smat.set_shader_parameter("color", glow_col.lerp(Color(0.6, 0.85, 1.0), 0.5))
		shield.material_override = smat
		shield.position.y = r * 0.35
		shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield.visible = false
		add_child(shield)


func _build_ring() -> void:
	if _ring_mesh == null:
		_ring_mesh = QuadMesh.new()
		_ring_mesh.size = Vector2(2, 2)
		_ring_mesh.orientation = PlaneMesh.FACE_Y
	ring = MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := 0.9
	match kind:
		Game.Kind.HERO: r = 1.25
		Game.Kind.TOWER: r = 3.2
		Game.Kind.ANCIENT: r = 6.0
		Game.Kind.FOUNTAIN: r = 4.0
		Game.Kind.CREEP_MELEE, Game.Kind.CREEP_RANGED: r = 0.8
		Game.Kind.CREEP_SIEGE: r = 1.15
	ring.scale = Vector3(r, 1, r)
	ring.position.y = 0.04
	ring.material_override = ring_material(team, kind == Game.Kind.HERO, false) if kind < Game.Kind.TOWER else building_ring_material(team)
	add_child(ring)


static func building_ring_material(t: int) -> ShaderMaterial:
	var key := "bring_%d" % t
	if _ring_mats.has(key):
		return _ring_mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ring.gdshader")
	mat.set_shader_parameter("color", Color(Game.TEAM_COLORS[t], 0.28))
	mat.set_shader_parameter("inner", 0.9)
	mat.set_shader_parameter("shadow", 0.25)
	_ring_mats[key] = mat
	return mat


static func crystal_material(t: int) -> StandardMaterial3D:
	var key := "crystal_%d" % t
	if _tint_cache.has(key):
		return _tint_cache[key]
	var c: Color = Game.TEAM_COLORS[t]
	var m := StandardMaterial3D.new()
	m.albedo_color = c.lightened(0.35)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.1
	m.roughness = 0.15
	m.metallic = 0.4
	# bordo luminoso
	m.rim_enabled = true
	m.rim = 1.0
	m.rim_tint = 0.2
	_tint_cache[key] = m
	return m


static func ring_material(t: int, hero: bool, hovered: bool) -> ShaderMaterial:
	var key := "%d_%s_%s" % [t, hero, hovered]
	if _ring_mats.has(key):
		return _ring_mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ring.gdshader")
	var c: Color = Game.TEAM_COLORS[t] if t < 2 else Color.WHITE
	if hovered:
		c = Color(1.0, 0.25, 0.2)
	mat.set_shader_parameter("color", Color(c, 1.0 if (hero or hovered) else 0.75))
	mat.set_shader_parameter("shadow", 0.45)
	mat.set_shader_parameter("inner", 0.72 if hero else 0.8)
	mat.set_shader_parameter("pulse", 1.0 if (hero or hovered) else 0.0)
	_ring_mats[key] = mat
	return mat


func set_hover(h: bool) -> void:
	if h == hover or ring == null:
		return
	hover = h
	if kind >= Game.Kind.TOWER and not h:
		ring.material_override = building_ring_material(team)
	else:
		ring.material_override = ring_material(team, kind == Game.Kind.HERO, h)


# --- Animazione --------------------------------------------------------------

func play(a: String, blend: float = -1.0, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(a):
		return
	if a == cur_anim and anim.is_playing():
		anim.speed_scale = speed
		return
	cur_anim = a
	anim.play(a, blend)
	anim.speed_scale = speed


func play_attack(attack_point: float) -> void:
	if anim == null:
		return
	var a: String = cfg.get("attack", "")
	if not anim.has_animation(a):
		return
	var length := anim.get_animation(a).length
	# il "punto d'impatto" della clip coincide con il momento del danno
	var speed := clampf((length * cfg.get("impact", 0.4)) / maxf(attack_point, 0.05), 0.6, 3.5)
	cur_anim = ""
	play(a, 0.08, speed)
	lock_t = length / speed


func play_cast(slot: int) -> void:
	if anim == null:
		return
	var casts: Array = cfg.get("casts", [])
	if slot < 0 or slot >= casts.size():
		return
	var a: String = casts[slot][0]
	if not anim.has_animation(a):
		return
	var length := anim.get_animation(a).length
	var speed: float = casts[slot][1]
	cur_anim = ""
	play(a, 0.06, speed)
	lock_t = minf(length / speed, 0.9)


func play_spawn() -> void:
	var a: String = cfg.get("spawn", "")
	if anim and a != "" and anim.has_animation(a):
		cur_anim = ""
		play(a, 0.0, 1.6)
		lock_t = anim.get_animation(a).length / 1.6


func flash() -> void:
	flash_t = 0.12
	_set_flash(true)


func _set_flash(on: bool) -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1, 0.85, 0.8, 0.55)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat if on else null


func die() -> void:
	if dead:
		return
	dead = true
	death_t = 0.0
	if ring:
		ring.visible = false
	set_hover(false)
	if building_model != null:
		collapse_t = 0.0
		if shield: shield.visible = false
		return
	if anim:
		var a: String = cfg.get("death", "Death_A")
		cur_anim = ""
		play(a, 0.1, 1.0)


func revive() -> void:
	dead = false
	death_t = 0.0
	visible = true
	_reset_visual()


## Avanza l'animazione dei creep a frequenza ridotta; on_screen=false la sospende.
func tick_anim(delta: float, on_screen: bool, frame: int) -> void:
	if anim == null or kind == Game.Kind.HERO:
		return
	anim_accum += delta
	if not on_screen and not dead:
		return
	if (frame + anim_phase) % 2 == 0 or anim_accum > 0.05:
		anim.advance(anim_accum)
		anim_accum = 0.0


## Aggiornamento per frame chiamato da World.
## moving/attacking derivano dallo stato dell'unità; speed = velocità reale per adattare la camminata.
func update_visual(delta: float, p: Vector3, f: float, moving: bool, speed: float, invulnerable: bool, stunned: bool, shielded: bool = false, empower: bool = false) -> void:
	vis_pos = p
	position = p
	if shielded or buff_shield:
		_update_buff_shield(delta, shielded and not dead)
	if stunned or stun_fx:
		_update_stun_fx(delta, stunned and not dead)
	if totem_rune and empower != empowered:
		_set_empowered(empower and not dead)
	if hop_t >= 0.0 and model:
		_update_hop(delta)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			_set_flash(false)
	if building_model != null:
		_update_building(delta, invulnerable)
		return
	_update_wake(p, moving)
	if dead:
		if stun_fx:
			stun_fx.visible = false
		death_t += delta
		# dopo l'animazione di morte il corpo sprofonda nel terreno
		if death_t > 1.6 and model:
			model.position.y = -minf((death_t - 1.6) * 0.8, 1.5)
		return
	facing = lerp_angle(facing, f, minf(1.0, delta * 14.0))
	rotation.y = -facing + PI * 0.5
	if lock_t > 0.0:
		lock_t -= delta
		if not moving:
			return
		lock_t = 0.0   # muoversi interrompe l'animazione d'attacco (come in Dota)
	if stunned:
		play(cfg.get("idle", "Idle"), 0.1, 0.2)
	elif moving:
		var ref: float = cfg.get("run_ref", 5.0)
		play(cfg.move, 0.12, clampf(speed / ref, 0.7, 1.7))
	else:
		play(cfg.idle, 0.18, 1.0)


func _update_buff_shield(delta: float, on: bool) -> void:
	if buff_shield == null:
		buff_shield = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.25
		sm.height = 2.5
		sm.radial_segments = 20
		sm.rings = 10
		buff_shield.mesh = sm
		var key := "buff_shield_%d" % team
		var mat: ShaderMaterial = _tint_cache.get(key)
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = load("res://scripts/vfx/shield.gdshader")
			mat.set_shader_parameter("color", Color(1.0, 0.82, 0.4) if team == 0 else Color(0.8, 0.55, 1.0))
			mat.set_shader_parameter("strength", 1.1)
			_tint_cache[key] = mat
		buff_shield.material_override = mat
		buff_shield.position.y = 1.05
		buff_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(buff_shield)
	buff_shield.visible = on
	if on:
		buff_shield.rotation.y += delta * 1.5


## Mostra le increspature quando l'unità (viva) ha i piedi sotto il pelo dell'acqua.
func _update_wake(p: Vector3, moving: bool) -> void:
	var wet := not dead and p.y < Terrain.WATER_Y - 0.05
	if not wet:
		if wake:
			wake.visible = false
		return
	if wake == null:
		if _wake_mat == null:
			_wake_mat = ShaderMaterial.new()
			_wake_mat.shader = load("res://scripts/world/wake.gdshader")
		wake = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(3.2, 3.2)
		q.orientation = PlaneMesh.FACE_Y
		wake.mesh = q
		wake.material_override = _wake_mat
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wake)
	wake.visible = true
	wake.position.y = Terrain.WATER_Y - p.y + 0.02
	wake.set_instance_shader_parameter("strength", 1.0 if moving else 0.45)


func _update_building(delta: float, invulnerable: bool) -> void:
	if crystal:
		crystal.rotation.y += delta * 0.8
		crystal.position.y += sin(Time.get_ticks_msec() * 0.002 + unit_id) * delta * 0.3
	if light and kind == Game.Kind.ANCIENT and not dead:
		light.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.0025) * 0.6   # "respira"
	if shield:
		shield.visible = invulnerable and not dead
	if collapse_t >= 0.0 and collapse_t < 3.0:
		collapse_t += delta
		var k := clampf(collapse_t / 1.6, 0.0, 1.0)
		building_model.position.y = -k * k * height * 0.8
		building_model.rotation.z = k * 0.35
		if crystal:
			crystal.visible = false
		if light:
			light.visible = false
		if collapse_t >= 1.6 and rubble == null:
			rubble = (load(ENV + "building_destroyed.gltf") as PackedScene).instantiate()
			rubble.scale = Vector3.ONE * (3.5 if kind != Game.Kind.ANCIENT else 6.0)
			add_child(rubble)
			building_model.visible = false
