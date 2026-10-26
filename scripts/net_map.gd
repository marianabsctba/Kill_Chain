class_name NetMap
extends Control
## Mapa da rede desenhado em tempo real: nós com brilho, pacotes andando
## pelos links e anel pulsante no host conectado. Clique num nó para conectar.

signal node_clicked(id: String)

const RADIUS := 20.0
const MARGIN := 70.0
const STATE_COLORS := {
	"alerta": UiTheme.WARN,
	"comprometido": UiTheme.DANGER,
	"isolado": UiTheme.DIM,
	"seguro": UiTheme.OK,
}
const TYPE_GLYPHS := {
	"estacao": "PC",
	"servidor": "SV",
	"firewall": "FW",
	"banco": "DB",
	"nuvem": "WEB",
	"backup": "BK",
	"dc": "DC",
}

var _t := 0.0
var _hovered := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.network_changed.connect(queue_redraw)
	Game.host_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _visible_ids() -> Array:
	return Game.hosts().keys().filter(func(id): return Game.revealed.has(id))


func _pos(id: String) -> Vector2:
	var p: Array = Game.host(id).get("pos", [0.5, 0.5])
	return Vector2(
		MARGIN + float(p[0]) * (size.x - 2.0 * MARGIN),
		MARGIN + float(p[1]) * (size.y - 2.0 * MARGIN))


func _color(id: String) -> Color:
	return STATE_COLORS.get(Game.host_state.get(id, "normal"), UiTheme.accent)


func _draw() -> void:
	var font := get_theme_default_font()
	var accent := UiTheme.accent

	var grid := Color(accent, 0.045)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid)
		x += 32.0
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid)
		y += 32.0

	draw_string(font, Vector2(16, 26), "MAPA DA REDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(accent, 0.7))

	var ids := _visible_ids()
	for link in Game.mission.get("links", []):
		var a_id := str(link[0])
		var b_id := str(link[1])
		if not (ids.has(a_id) and ids.has(b_id)):
			continue
		var a := _pos(a_id)
		var b := _pos(b_id)
		var isolated: bool = Game.host_state.get(a_id) == "isolado" or Game.host_state.get(b_id) == "isolado"
		draw_line(a, b, Color(accent, 0.12 if isolated else 0.3), 1.5, true)
		if not isolated:
			var phase := float(absi(hash(a_id + b_id)) % 1000) / 1000.0
			for i in 2:
				var k := fmod(_t * 0.3 + phase + i * 0.5, 1.0)
				draw_circle(a.lerp(b, k), 2.5, Color(accent, 0.9))

	for id in ids:
		var p := _pos(id)
		var col := _color(id)
		var h := Game.host(id)
		for i in range(5, 0, -1):
			draw_circle(p, RADIUS + i * 4.0, Color(col, 0.035))
		draw_circle(p, RADIUS, UiTheme.BG)
		draw_arc(p, RADIUS, 0, TAU, 40, col, 2.0, true)
		var glyph: String = TYPE_GLYPHS.get(h.get("tipo", ""), "#")
		draw_string(font, p + Vector2(-RADIUS, 5), glyph, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 12, col)
		if id == Game.host_id:
			var r := RADIUS + 8.0 + sin(_t * 4.0) * 3.0
			draw_arc(p, r, 0, TAU, 48, Color(col, 0.8), 1.5, true)
		if id == _hovered:
			draw_arc(p, RADIUS + 4.0, 0, TAU, 40, Color.WHITE, 1.0, true)
		draw_string(font, p + Vector2(-130, RADIUS + 20), str(h.get("nome", id)), HORIZONTAL_ALIGNMENT_CENTER, 260, 15, UiTheme.TEXT)
		draw_string(font, p + Vector2(-130, RADIUS + 38), str(h.get("ip", "")), HORIZONTAL_ALIGNMENT_CENTER, 260, 13, UiTheme.DIM)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found := ""
		for id in _visible_ids():
			if _pos(id).distance_to(event.position) <= RADIUS + 6.0:
				found = id
		_hovered = found
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if found else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _hovered.is_empty():
			node_clicked.emit(_hovered)
