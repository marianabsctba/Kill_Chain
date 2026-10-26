extends Control
## Fluxo de telas: boot, perfil, menu de missões e a mesa de trabalho.
## F2 liga e desliga o efeito CRT. F11 alterna tela cheia.

var _root: Control
var _crt_layer: CanvasLayer
var _crt_mat: ShaderMaterial
var _screen := ""

var _terminal: Terminal
var _shell: Shell
var _mission_label: Label
var _clock: Label
var _objectives_text: RichTextLabel
var _inbox_text: RichTextLabel
var _cards_text: RichTextLabel


func _ready() -> void:
	theme = UiTheme.build()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_setup_crt()

	Game.accent_changed.connect(_on_accent_changed)
	Game.mail_received.connect(_on_mail)
	Game.objective_completed.connect(_on_objective)
	Game.mission_finished.connect(_on_mission_finished)
	_show_boot()


func _process(_delta: float) -> void:
	if is_instance_valid(_clock):
		_clock.text = Time.get_time_string_from_system()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F2:
				_crt_layer.visible = not _crt_layer.visible
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _screen == "boot":
					_after_boot()
	elif event is InputEventMouseButton and event.pressed and _screen == "boot":
		_after_boot()


# Efeitos

func _setup_crt() -> void:
	_crt_layer = CanvasLayer.new()
	_crt_layer.layer = 100
	add_child(_crt_layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = load("res://shaders/crt.gdshader")
	rect.material = _crt_mat
	_crt_layer.add_child(rect)


func glitch(amount := 0.6, duration := 0.35) -> void:
	_crt_mat.set_shader_parameter("glitch", amount)
	create_tween().tween_property(_crt_mat, "shader_parameter/glitch", 0.0, duration)


func _on_accent_changed() -> void:
	theme = UiTheme.build()
	if is_instance_valid(_terminal):
		_terminal.refresh_colors()
		_refresh_side()


# Utilidades de layout

func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_terminal = null
	_clock = null


func _center_panel(width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, Color(UiTheme.accent, 0.5), 1, 4, 28.0))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	return v


func _label(parent: Control, text: String, color := UiTheme.TEXT, font_size := 16) -> Label:
	var l := Label.new()
	l.text = text
	# Em linhas horizontais a quebra automática espreme o texto em uma letra por linha.
	if not parent is HBoxContainer:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _toggle(parent: Control, text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


func _rich(parent: Control) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_following = false
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.meta_clicked.connect(func(meta):
		if is_instance_valid(_terminal):
			_terminal.run(str(meta))
			_terminal.focus())
	parent.add_child(r)
	return r


# Tela 1: boot

func _show_boot() -> void:
	_clear()
	_screen = "boot"
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 48
	label.offset_top = 40
	_root.add_child(label)

	var ok := "[color=%s][lb] ok [rb][/color] " % UiTheme.hex(UiTheme.OK)
	var lines := [
		"[color=%s]AURORA//OS 4.7  CSIRT Aurora, uso restrito[/color]" % UiTheme.hex(UiTheme.DIM),
		"",
		ok + "verificando integridade do sistema",
		ok + "carregando módulos de telemetria",
		ok + "sincronizando relógio com a central",
		ok + "montando cofre de evidências",
		ok + "abrindo canal seguro com a coordenação",
		"",
		"[color=%s]  ╔════════════════════════════════════╗[/color]" % UiTheme.hex(UiTheme.accent),
		"[color=%s]  ║      K I L L  / /  C H A I N       ║[/color]" % UiTheme.hex(UiTheme.accent),
		"[color=%s]  ╚════════════════════════════════════╝[/color]" % UiTheme.hex(UiTheme.accent),
		"",
		"[color=%s]pressione ENTER para continuar[/color]" % UiTheme.hex(UiTheme.WARN),
	]
	for l in lines:
		if not is_instance_valid(label) or _screen != "boot":
			return
		label.append_text(l + "\n")
		await get_tree().create_timer(0.11).timeout


func _after_boot() -> void:
	glitch(0.8, 0.4)
	if Game.has_profile():
		_show_menu()
	else:
		_show_profile()


# Tela 2: perfil

func _show_profile() -> void:
	_clear()
	_screen = "perfil"
	var box := _center_panel(560)
	_label(box, "IDENTIFICAÇÃO", UiTheme.accent, 22)

	_label(box, "nome ou codinome", UiTheme.DIM, 14)
	var name_edit := LineEdit.new()
	name_edit.max_length = 20
	name_edit.text = Game.player_name
	name_edit.placeholder_text = "ex.: Mari"
	name_edit.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0.35), UiTheme.PANEL_BORDER, 1, 3, 8.0))
	box.add_child(name_edit)

	_label(box, "personagem", UiTheme.DIM, 14)
	var gender_row := HBoxContainer.new()
	box.add_child(gender_row)
	var gender_group := ButtonGroup.new()
	var masc := _toggle(gender_row, "Masculino", gender_group)
	var fem := _toggle(gender_row, "Feminino", gender_group)
	(masc if Game.gender == Game.Gender.MASCULINO else fem).button_pressed = true

	_label(box, "cor do terminal", UiTheme.DIM, 14)
	var color_row := HBoxContainer.new()
	box.add_child(color_row)
	var color_group := ButtonGroup.new()
	for accent_name in UiTheme.ACCENTS:
		var b := _toggle(color_row, accent_name, color_group)
		b.add_theme_color_override("font_color", UiTheme.ACCENTS[accent_name])
		b.button_pressed = accent_name == Game.accent_name
		b.pressed.connect(func(): Game.set_accent(accent_name))

	var err := _label(box, "", UiTheme.DANGER, 14)
	var confirm := Button.new()
	confirm.text = "CONFIRMAR"
	box.add_child(confirm)

	var submit := func(_t = ""):
		var n := name_edit.text.strip_edges()
		if n.is_empty():
			err.text = "informe um nome"
			return
		Game.player_name = n
		Game.gender = Game.Gender.MASCULINO if masc.button_pressed else Game.Gender.FEMININO
		Game.save_profile()
		glitch(0.5)
		_show_menu()
	confirm.pressed.connect(submit)
	name_edit.text_submitted.connect(submit)
	name_edit.grab_focus.call_deferred()


# Tela 3: menu de missões

func _show_menu() -> void:
	_clear()
	_screen = "menu"
	var box := _center_panel(760)
	_label(box, "KILL//CHAIN", UiTheme.accent, 30)
	_label(box, Game.fmt("Bem-vind{o|a}, {nome}. Escolha um caso."), UiTheme.DIM)

	var missions := Game.list_missions()
	if missions.is_empty():
		_label(box, "nenhuma missão encontrada em %s" % Game.MISSIONS_DIR, UiTheme.WARN)
	for m in missions:
		var b := Button.new()
		b.text = "%s\n%s" % [m.get("titulo", m.get("id", "?")), Game.fmt(m.get("resumo", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_start_mission.bind(m))
		box.add_child(b)

	var profile := Button.new()
	profile.text = "editar perfil"
	profile.flat = true
	profile.pressed.connect(_show_profile)
	box.add_child(profile)
	_label(box, "F2 liga/desliga o efeito CRT   F11 tela cheia", UiTheme.DIM, 12)


# Tela 4: mesa de trabalho

func _start_mission(m: Dictionary) -> void:
	_build_desk()
	_mission_label.text = str(m.get("titulo", ""))
	if m.has("intro"):
		for l in Game.fmt(m["intro"]).split("\n"):
			_terminal.write(l, UiTheme.DIM)
	_terminal.write("digite help para ver os comandos, mail para ler mensagens", UiTheme.DIM)
	Game.start_mission(m)
	_terminal.set_prompt(_shell.prompt())
	_write_current_objective()
	_refresh_side()
	_terminal.focus()
	glitch(0.7, 0.5)


func _build_desk() -> void:
	_clear()
	_screen = "mesa"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var top := PanelContainer.new()
	v.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 24)
	top.add_child(bar)
	_label(bar, "KILL//CHAIN", UiTheme.accent, 18)
	_mission_label = _label(bar, "", UiTheme.TEXT)
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var who := _label(bar, "analista: " + Game.player_name, UiTheme.DIM)
	who.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clock = _label(bar, "", UiTheme.accent)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	var menu := Button.new()
	menu.text = "menu"
	menu.flat = true
	menu.pressed.connect(_show_menu)
	bar.add_child(menu)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	v.add_child(body)

	_terminal = Terminal.new()
	_terminal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terminal.size_flags_stretch_ratio = 1.15
	body.add_child(_terminal)
	_shell = Shell.new(_terminal)
	_terminal.completer = _shell.complete
	_terminal.command_entered.connect(_on_command)

	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.25), UiTheme.PANEL_BORDER, 1, 4, 0.0))
	body.add_child(map_panel)
	var net_map := NetMap.new()
	map_panel.add_child(net_map)
	net_map.node_clicked.connect(func(id):
		_terminal.run("connect " + id)
		_terminal.focus())

	var tabs := TabContainer.new()
	tabs.custom_minimum_size.x = 360
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_stretch_ratio = 0.6
	body.add_child(tabs)
	_objectives_text = _rich(tabs)
	_inbox_text = _rich(tabs)
	_cards_text = _rich(tabs)
	tabs.set_tab_title(0, "objetivos")
	tabs.set_tab_title(1, "e-mail")
	tabs.set_tab_title(2, "ATT&CK")


func _on_command(line: String) -> void:
	_shell.run(line)
	_refresh_side()


func _write_current_objective() -> void:
	if Game.is_finished():
		return
	var obj := Game.current_objective()
	_terminal.write("objetivo: " + Game.fmt(obj.get("texto", "")), UiTheme.accent)


func _refresh_side() -> void:
	if not is_instance_valid(_terminal):
		return
	var accent := UiTheme.hex(UiTheme.accent)
	var ok := UiTheme.hex(UiTheme.OK)
	var dim := UiTheme.hex(UiTheme.DIM)

	var t := ""
	var objs := Game.objectives()
	for i in objs.size():
		var text := Terminal.esc(Game.fmt(objs[i].get("texto", "")))
		if i < Game.objective_index:
			t += "[color=%s][lb]x[rb] %s[/color]\n\n" % [ok, text]
		elif i == Game.objective_index:
			t += "[color=%s][lb] [rb] %s[/color]\n" % [accent, text]
			if objs[i].has("dica"):
				t += "[color=%s]    dica: %s[/color]\n" % [dim, Terminal.esc(Game.fmt(objs[i]["dica"]))]
			t += "\n"
		else:
			t += "[color=%s][lb] [rb] ???[/color]\n\n" % dim
	_objectives_text.text = t

	t = ""
	if Game.inbox.is_empty():
		t = "[color=%s]nenhuma mensagem[/color]" % dim
	for i in Game.inbox.size():
		var m: Dictionary = Game.inbox[i]
		var mark := "  " if Game.read_mail.has(i) else "[color=%s]* [/color]" % UiTheme.hex(UiTheme.WARN)
		t += "%s[url=mail %d]%s[/url]\n   [color=%s]%s[/color]\n\n" % [
			mark, i + 1, Terminal.esc(Game.fmt(m.get("assunto", ""))),
			dim, Terminal.esc(Game.fmt(m.get("de", "")))]
	_inbox_text.text = t

	t = ""
	if Game.unlocked_cards.is_empty():
		t = "[color=%s]as fichas aparecem conforme você avança no caso[/color]" % dim
	for id in Game.unlocked_cards:
		t += "[url=fichas %s][color=%s]%s[/color][/url]\n%s\n\n" % [
			id, accent, id, Terminal.esc(Game.card(id).get("nome", ""))]
	_cards_text.text = t


func _on_mail(mail: Dictionary) -> void:
	if not is_instance_valid(_terminal):
		return
	_terminal.write("nova mensagem: %s (digite mail %d)" % [Game.fmt(mail.get("assunto", "")), Game.inbox.size()], UiTheme.WARN)
	glitch(0.35, 0.25)
	_refresh_side()


func _on_objective(obj: Dictionary) -> void:
	if not is_instance_valid(_terminal):
		return
	_terminal.write("objetivo concluído: " + Game.fmt(obj.get("texto", "")), UiTheme.OK)
	for c in obj.get("fichas", []):
		_terminal.write("ficha ATT&CK desbloqueada: %s %s (digite fichas %s)" % [c, Game.card(c).get("nome", ""), c], UiTheme.accent)
	glitch(0.45, 0.3)
	_write_current_objective()
	_refresh_side()


func _on_mission_finished() -> void:
	await get_tree().create_timer(1.2).timeout
	if _screen != "mesa":
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)
	var box := _center_panel(720)
	_label(box, "CASO ENCERRADO", UiTheme.OK, 26)
	_label(box, Game.fmt(Game.mission.get("debrief", "")))
	if not Game.unlocked_cards.is_empty():
		_label(box, "fichas conquistadas", UiTheme.DIM, 14)
		for id in Game.unlocked_cards:
			_label(box, "%s  %s" % [id, Game.card(id).get("nome", "")], UiTheme.accent)
	var back := Button.new()
	back.text = "VOLTAR AO MENU"
	back.pressed.connect(_show_menu)
	box.add_child(back)
	glitch(0.9, 0.6)
