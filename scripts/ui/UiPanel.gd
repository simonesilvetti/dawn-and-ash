class_name UiPanel
extends PanelContainer
## Pannello ornato disegnato da ui_panel.gdshader (fondo con grana, doppia cornice dorata, ornamenti).
## Si usa come un PanelContainer: i margini interni vengono dallo StyleBoxEmpty.

static var _white: ImageTexture
static var _shader: Shader

var margin := 12


func _init(m: int = 12, ornaments: bool = true, radius: float = 10.0) -> void:
	margin = m
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m - 2
	sb.content_margin_bottom = m - 2
	add_theme_stylebox_override("panel", sb)
	if _shader == null:
		_shader = load("res://scripts/ui/ui_panel.gdshader")
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("noise_tex", MapBuilder.noise_texture())
	mat.set_shader_parameter("ornaments", ornaments)
	mat.set_shader_parameter("radius", radius)
	material = mat
	resized.connect(func(): (material as ShaderMaterial).set_shader_parameter("size", size))


func _draw() -> void:
	draw_texture_rect(_white, Rect2(Vector2.ZERO, size), false)
