class_name UiTheme
extends RefCounted
## Paleta e tema visual do jogo. Tudo é gerado em código para facilitar
## trocar a cor de destaque em tempo real.

const BG := Color("05080d")
const PANEL := Color("0a121b")
const PANEL_BORDER := Color("16303d")
const TEXT := Color("e2f4fa")
const DIM := Color("86a3b1")
const DANGER := Color("ff3d5a")
const WARN := Color("ffb020")
const OK := Color("39ff88")

const ACCENTS := {
	"ciano": Color("3ef0ff"),
	"verde": Color("39ff88"),
	"roxo": Color("b26bff"),
}

static var accent: Color = ACCENTS["ciano"]
static var _font: Font
static var _bold: Font


static func set_accent(name: String) -> void:
	accent = ACCENTS.get(name, ACCENTS["ciano"])


## Fonte embutida (JetBrains Mono, licença OFL em fonts/OFL.txt), porque a
## versão web não tem acesso às fontes do sistema.
static func mono_font() -> Font:
	if _font == null:
		_font = load("res://fonts/JetBrainsMono-Regular.ttf")
	return _font


static func bold_font() -> Font:
	if _bold == null:
		_bold = load("res://fonts/JetBrainsMono-Bold.ttf")
	return _bold


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


static func box(bg: Color, border: Color, width := 1, radius := 4, margin := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func build() -> Theme:
	var t := Theme.new()
	var font := mono_font()
	t.default_font = font
	t.default_font_size = 18

	t.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_BORDER))
	t.set_stylebox("panel", "Panel", box(PANEL, PANEL_BORDER))

	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4.0))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("selection_color", "LineEdit", Color(accent, 0.3))

	t.set_stylebox("normal", "Button", box(Color(accent, 0.06), Color(accent, 0.45), 1, 3, 8.0))
	t.set_stylebox("hover", "Button", box(Color(accent, 0.16), accent, 1, 3, 8.0))
	t.set_stylebox("pressed", "Button", box(Color(accent, 0.32), accent, 2, 3, 8.0))
	t.set_stylebox("hover_pressed", "Button", box(Color(accent, 0.36), accent, 2, 3, 8.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", accent)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)

	t.set_color("default_color", "RichTextLabel", TEXT)
	for k in ["normal_font", "italics_font", "mono_font"]:
		t.set_font(k, "RichTextLabel", font)
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("panel", "TabContainer", box(PANEL, PANEL_BORDER))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(accent, 0.18), accent, 1, 3, 8.0))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0, 0, 0, 0), PANEL_BORDER, 1, 3, 8.0))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(accent, 0.08), Color(accent, 0.5), 1, 3, 8.0))
	t.set_color("font_selected_color", "TabContainer", accent)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	return t
