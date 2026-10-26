class_name Season
extends RefCounted
## Telas de temporada: matriz ATT&CK, encerramento (THE END) e certificado.

const NUMBER := 1
const SITE := "marianabsctba.github.io/Kill_Chain"


static func _label(parent: Control, text: String, color := UiTheme.TEXT, font_size := 16, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


static func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b


static func stats() -> Dictionary:
	var techniques := Game.season_techniques()
	var found := 0
	for id in techniques:
		if techniques[id]["found"]:
			found += 1
	var missions := Game.list_missions()
	var done := 0
	for m in missions:
		if Game.completed_missions.has(str(m.get("id", ""))):
			done += 1
	var score := Game.season_score()
	var average := score / maxi(done, 1)
	return {
		"techniques": techniques, "found": found, "total": techniques.size(),
		"missions": missions.size(), "done": done,
		"score": score, "max": missions.size() * 1000, "rank": Game.score_rank(average),
	}


# Matriz ATT&CK

static func build_matrix(parent: Control, on_back: Callable) -> void:
	var s := stats()
	var techniques: Dictionary = s["techniques"]

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	parent.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := _label(top, "MATRIZ ATT&CK  ·  TEMPORADA %d" % NUMBER, UiTheme.accent, 26)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_button(top, "VOLTAR", on_back)

	_label(v, "%d de %d técnicas da temporada descobertas. Clique numa técnica para ver a ficha. Colunas apagadas são táticas que ainda não apareceram nos casos." % [s["found"], s["total"]], UiTheme.DIM, 14)

	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size.y = 150
	detail.text = "[color=%s]selecione uma técnica descoberta[/color]" % UiTheme.hex(UiTheme.DIM)
	detail.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 6)
	v.add_child(columns)

	for tactic in AttackData.TACTICS:
		var ids: Array = []
		var found_here := 0
		for id in techniques:
			if AttackData.tactics_for(id, techniques[id]["card"]).has(tactic[0]):
				ids.append(id)
				if techniques[id]["found"]:
					found_here += 1
		ids.sort()

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := UiTheme.accent if found_here > 0 else UiTheme.PANEL_BORDER
		panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, Color(border, 0.6), 1, 3, 6.0))
		if ids.is_empty():
			panel.modulate.a = 0.45
		columns.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		# Quebra só entre palavras: "Reconhecimento" não pode virar "Reconhecime/nto".
		var header := _label(col, tactic[1], UiTheme.accent if found_here > 0 else UiTheme.DIM, 11, true)
		header.autowrap_mode = TextServer.AUTOWRAP_WORD
		_label(col, "%d/%d" % [found_here, ids.size()], UiTheme.DIM, 11, true)

		for id in ids:
			var b := Button.new()
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 11)
			var card: Dictionary = techniques[id]["card"]
			if techniques[id]["found"]:
				b.text = "%s\n%s" % [id, card.get("nome", "")]
				b.pressed.connect(func(): detail.text = _card_bbcode(id, card))
			else:
				b.text = "???"
				b.disabled = true
				b.tooltip_text = "técnica de um caso ainda não concluído"
			col.add_child(b)

	var detail_panel := PanelContainer.new()
	v.add_child(detail_panel)
	detail_panel.add_child(detail)


static func _card_bbcode(id: String, card: Dictionary) -> String:
	var t := "[color=%s][b]%s  %s[/b][/color]\n" % [UiTheme.hex(UiTheme.accent), id, Terminal.esc(str(card.get("nome", "")))]
	var tactics := PackedStringArray()
	for tac in AttackData.tactics_for(id, card):
		tactics.append(AttackData.tactic_name(tac))
	t += "[color=%s]tática: %s[/color]\n" % [UiTheme.hex(UiTheme.DIM), ", ".join(tactics)]
	t += Terminal.esc(Game.fmt(str(card.get("descricao", "")))) + "\n"
	if card.has("defesa"):
		t += "[color=%s]como se defender: %s[/color]\n" % [UiTheme.hex(UiTheme.OK), Terminal.esc(Game.fmt(str(card["defesa"])))]
	if card.has("url"):
		t += "[url=%s]%s[/url]" % [card["url"], card["url"]]
	return t


# Encerramento

## Monta a tela THE END. on_glitch recebe (intensidade, duração).
static func build_the_end(parent: Control, actions: Dictionary, on_glitch: Callable) -> void:
	var s := stats()
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size.x = 900
	center.add_child(v)

	var the_end := _label(v, "THE END", UiTheme.accent, 120, true)
	the_end.add_theme_font_override("font", UiTheme.bold_font())
	var soon := _label(v, "Continua em breve...", UiTheme.DIM, 28, true)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	v.add_child(gap)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	v.add_child(info)
	_label(info, Game.fmt("Temporada %d concluída, {nome}." % NUMBER), UiTheme.TEXT, 22, true)
	_label(info, "pontuação total: %d de %d  |  classificação %s  |  técnicas descobertas: %d de %d" % [
		s["score"], s["max"], s["rank"], s["found"], s["total"]], UiTheme.accent, 16, true)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 16
	info.add_child(gap2)
	_label(info, "KILL CHAIN", UiTheme.TEXT, 18, true)
	_label(info, "criação e roteiro: Mariana BS", UiTheme.DIM, 14, true)
	_label(info, "Powered by Mariana BS", UiTheme.DIM, 14, true)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_button(row, "MATRIZ ATT&CK", actions["matriz"])
	var cert := Button.new()
	cert.text = "BAIXAR CERTIFICADO"
	row.add_child(cert)
	cert.pressed.connect(func():
		cert.disabled = true
		cert.text = "GERANDO..."
		var tree := cert.get_tree()
		actions["certificado"].call()
		await tree.create_timer(1.0).timeout
		if is_instance_valid(cert):
			cert.disabled = false
			cert.text = "BAIXAR CERTIFICADO")
	_button(row, "MENU", actions["menu"])

	the_end.modulate.a = 0.0
	soon.visible_ratio = 0.0
	info.modulate.a = 0.0
	row.modulate.a = 0.0
	var tw := parent.create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(on_glitch.bind(1.0, 0.8))
	tw.tween_property(the_end, "modulate:a", 1.0, 1.4)
	tw.tween_property(soon, "visible_ratio", 1.0, 1.6)
	tw.tween_interval(0.6)
	tw.tween_property(info, "modulate:a", 1.0, 1.0)
	tw.tween_property(row, "modulate:a", 1.0, 0.6)


# Certificado

## Desenha o certificado numa SubViewport e devolve a imagem.
static func certificate_image(host: Node) -> Image:
	var s := stats()
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)

	var root := Control.new()
	root.theme = UiTheme.build()
	root.size = Vector2(vp.size)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.size = root.size
	root.add_child(bg)
	var frame := Panel.new()
	frame.position = Vector2(36, 36)
	frame.size = root.size - Vector2(72, 72)
	frame.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.accent, 3, 6, 0.0))
	root.add_child(frame)

	var v := VBoxContainer.new()
	v.position = Vector2(140, 110)
	v.size = Vector2(root.size.x - 280, root.size.y - 220)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)

	var title := _label(v, "KILL CHAIN", UiTheme.accent, 64, true)
	title.add_theme_font_override("font", UiTheme.bold_font())
	_label(v, "CERTIFICADO DE CONCLUSÃO  ·  TEMPORADA %d" % NUMBER, UiTheme.TEXT, 24, true)
	_label(v, "Certificamos que", UiTheme.DIM, 20, true)
	var who := _label(v, Game.player_name, Color.WHITE, 56, true)
	who.add_theme_font_override("font", UiTheme.bold_font())
	_label(v, Game.fmt("concluiu a primeira temporada do Kill Chain como analista do CSIRT Aurora, investigando %d casos de incidentes e descobrindo %d técnicas do MITRE ATT&CK." % [s["done"], s["found"]]), UiTheme.TEXT, 20, true)
	_label(v, "pontuação %d de %d  |  classificação %s" % [s["score"], s["max"], s["rank"]], UiTheme.accent, 22, true)

	var ids := PackedStringArray()
	for id in s["techniques"]:
		if s["techniques"][id]["found"]:
			ids.append(id)
	ids.sort()
	_label(v, "  ".join(ids), UiTheme.DIM, 14, true)
	var date := Time.get_date_dict_from_system()
	_label(v, "%02d/%02d/%d" % [date["day"], date["month"], date["year"]], UiTheme.DIM, 16, true)
	_label(v, "Powered by Mariana BS  ·  %s" % SITE, UiTheme.DIM, 14, true)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## Salva o certificado: no navegador vira download, no desktop abre o PNG.
static func save_certificate(img: Image) -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), "certificado-kill-chain.png", "image/png")
		return "download iniciado"
	var path := "user://certificado-kill-chain.png"
	img.save_png(path)
	OS.shell_open(ProjectSettings.globalize_path(path))
	return ProjectSettings.globalize_path(path)
