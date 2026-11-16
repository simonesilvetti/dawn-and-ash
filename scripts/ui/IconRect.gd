class_name IconRect
extends ColorRect
## Icona procedurale (icon.gdshader) di un'abilità o di un oggetto. symbol = id dell'abilità/oggetto.

const IDS := {"fireball": 0, "blink": 1, "shockwave": 2, "meteor": 3,
	"cleave": 4, "charge": 5, "iron_shield": 6, "earthsplit": 7, "fissure": 8, "totem": 9,
	"aftershock": 19, "echo_slam": 20, "sword": 10, "armor": 11, "boots": 12,
	"vitality": 13, "potion": 14, "crystal": 15, "ring": 16, "mana_potion": 17, "vampire": 18}

static var _shader: Shader

var symbol := "":
	set(v):
		symbol = v
		visible = v != ""
		(material as ShaderMaterial).set_shader_parameter("icon", IDS.get(v, -1))
var dim := 0.0:
	set(v):
		if absf(v - dim) > 0.001:
			dim = v
			(material as ShaderMaterial).set_shader_parameter("dim", v)


func _init() -> void:
	if _shader == null:
		_shader = load("res://scripts/ui/icon.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("noise_tex", MapBuilder.noise_texture())
	material = m
	mouse_filter = Control.MOUSE_FILTER_IGNORE
