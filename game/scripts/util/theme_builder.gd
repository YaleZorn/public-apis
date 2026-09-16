extends RefCounted
class_name ThemeBuilder
## Runtime 9-slice chrome so portrait UI works without editor re-import of UI PNGs.

const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"
const UI_DIR := "res://assets/textures/ui/"


static func load_tex(name: String) -> Texture2D:
	var path := UI_DIR + name
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		# Fallback: try Image load even if .import is stale
		pass
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	if err != OK:
		# Direct res path
		err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


static func style_tex(tex: Texture2D, margin: float = 36.0, content: float = 14.0, pressed_shift: bool = false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	var top := content + (2.0 if pressed_shift else 0.0)
	var bot := content - (2.0 if pressed_shift else 0.0)
	sb.content_margin_left = content + 2.0
	sb.content_margin_right = content + 2.0
	sb.content_margin_top = top
	sb.content_margin_bottom = maxf(bot, 8.0)
	return sb


static func apply_ornate(theme: Theme) -> void:
	if theme == null:
		return
	var n := load_tex("btn_normal.png")
	var h := load_tex("btn_hover.png")
	var p := load_tex("btn_pressed.png")
	var d := load_tex("btn_disabled.png")
	var pri := load_tex("btn_primary.png")
	var pri_p := load_tex("btn_primary_pressed.png")
	var panel := load_tex("panel_frame.png")
	if n == null or h == null or p == null:
		return
	theme.set_stylebox("normal", "Button", style_tex(n))
	theme.set_stylebox("hover", "Button", style_tex(h))
	theme.set_stylebox("pressed", "Button", style_tex(p, 36.0, 14.0, true))
	if d:
		theme.set_stylebox("disabled", "Button", style_tex(d))
	if pri and pri_p:
		theme.set_type_variation("ButtonPrimary", "Button")
		theme.set_stylebox("normal", "ButtonPrimary", style_tex(pri, 36.0, 16.0))
		theme.set_stylebox("hover", "ButtonPrimary", style_tex(pri, 36.0, 16.0))
		theme.set_stylebox("pressed", "ButtonPrimary", style_tex(pri_p, 36.0, 16.0, true))
		theme.set_color("font_color", "ButtonPrimary", Color(0.98, 0.93, 0.72, 1))
		theme.set_color("font_hover_color", "ButtonPrimary", Color(1, 0.96, 0.78, 1))
		theme.set_font_size("font_size", "ButtonPrimary", 24)
	if panel:
		theme.set_stylebox("panel", "PanelContainer", style_tex(panel, 36.0, 12.0))
