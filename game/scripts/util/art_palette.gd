extends RefCounted
class_name ArtPalette
## Locked visual identity: ink-mist jade night + lantern gold (portrait wuxia / fitness).
## Avoid purple gradients, cream+terracotta cliché, and flat gray dashboards.

const INK_NIGHT := Color("071618")
const MIST_JADE := Color("14352F")
const DEEP_CLIFF := Color("0E2420")
const FOG_VEIL := Color(0.66, 0.77, 0.72, 0.18)
const LANTERN_GOLD := Color("E6C15A")
const LANTERN_SOFT := Color(0.90, 0.76, 0.42, 0.55)
const PAPER_INK := Color("E8E0D0")
const PAPER_DIM := Color(0.78, 0.74, 0.66, 0.92)
const MIST_TEAL := Color("5A9A90")
const PATH_EARTH := Color(0.42, 0.36, 0.24, 0.95)
const PATH_RIM := Color(0.28, 0.24, 0.16, 0.7)
const GATE_WOOD := Color(0.48, 0.34, 0.18, 0.98)
const GATE_SHADOW := Color(0.05, 0.08, 0.07, 0.92)
const PANEL_BG := Color(0.07, 0.12, 0.11, 0.94)
const PANEL_BORDER := Color(0.42, 0.55, 0.46, 0.85)
const BTN_BG := Color(0.14, 0.24, 0.20, 0.96)
const BTN_HOVER := Color(0.20, 0.32, 0.26, 1.0)
const BTN_BORDER := Color(0.55, 0.68, 0.48, 0.9)
const DANGER := Color(0.78, 0.36, 0.28, 0.95)
const OK_GREEN := Color(0.55, 0.82, 0.62, 1.0)

const FONT_PATH := "res://assets/fonts/LXGWWenKai-Regular.ttf"

static var _font: FontFile


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH) as FontFile
	return _font


static func apply_label(label: Label, size: int, color: Color = PAPER_INK) -> void:
	var f := font()
	if f:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func apply_richtext(rtl: RichTextLabel, size: int) -> void:
	var f := font()
	if f:
		rtl.add_theme_font_override("normal_font", f)
		rtl.add_theme_font_override("bold_font", f)
		rtl.add_theme_font_override("italics_font", f)
	rtl.add_theme_font_size_override("normal_font_size", size)
	rtl.add_theme_color_override("default_color", PAPER_DIM)


static func role_accent(role: String) -> Color:
	match role:
		"tank": return Color(0.42, 0.72, 0.55)
		"support": return Color(0.48, 0.86, 0.62)
		"control": return Color(0.45, 0.72, 0.88)
		"summon": return Color(0.92, 0.78, 0.40)
		_: return Color(0.92, 0.55, 0.32)


static func room_tint(rtype: String) -> Color:
	match rtype:
		"combat": return Color(0.16, 0.12, 0.12, 0.52)
		"event": return Color(0.10, 0.14, 0.22, 0.5)
		"train": return Color(0.10, 0.18, 0.14, 0.48)
		"supply": return Color(0.16, 0.14, 0.10, 0.48)
		"loot": return Color(0.18, 0.14, 0.08, 0.5)
		_: return Color(0.08, 0.12, 0.11, 0.45)
