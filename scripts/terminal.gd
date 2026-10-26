class_name Terminal
extends PanelContainer
## Terminal com efeito de digitação, histórico (setas) e autocompletar (Tab).

signal command_entered(line: String)

const CHARS_PER_SEC := 1400.0

var output: RichTextLabel
var input: LineEdit
var prompt_label: Label
var completer: Callable

var _history := PackedStringArray()
var _history_index := 0
var _reveal := 0.0


func _ready() -> void:
	var v := VBoxContainer.new()
	add_child(v)

	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.scroll_following = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.focus_mode = Control.FOCUS_NONE
	output.visible_characters = 0
	output.gui_input.connect(_on_output_gui)
	output.meta_clicked.connect(func(meta): run(str(meta)))
	v.add_child(output)

	var row := HBoxContainer.new()
	v.add_child(row)
	prompt_label = Label.new()
	row.add_child(prompt_label)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "digite help"
	input.context_menu_enabled = false
	input.caret_blink = true
	# Desde a Godot 4.4 o LineEdit sai do modo de edição ao apertar Enter;
	# no terminal queremos continuar digitando o próximo comando.
	input.keep_editing_on_text_submit = true
	input.text_submitted.connect(_on_submit)
	input.gui_input.connect(_on_input_gui)
	row.add_child(input)
	refresh_colors()


func _process(delta: float) -> void:
	var total := output.get_total_character_count()
	if output.visible_characters >= total:
		_reveal = total
		return
	var backlog := total - _reveal
	_reveal += maxf(CHARS_PER_SEC, backlog * 6.0) * delta
	output.visible_characters = mini(int(_reveal), total)


func refresh_colors() -> void:
	prompt_label.add_theme_color_override("font_color", UiTheme.accent)


func focus() -> void:
	input.grab_focus()
	input.edit()


func set_prompt(text: String) -> void:
	prompt_label.text = text + " "


## Escreve uma linha. O texto é escapado; use write_bb para BBCode.
func write(text: String, color: Color = UiTheme.TEXT) -> void:
	write_bb("[color=%s]%s[/color]" % [UiTheme.hex(color), esc(text)])


func write_bb(bbcode: String) -> void:
	output.append_text(bbcode + "\n")


func clear() -> void:
	output.clear()
	output.visible_characters = 0
	_reveal = 0.0


## Executa um comando como se o jogador tivesse digitado.
func run(line: String) -> void:
	_on_submit(line)


static func esc(s: String) -> String:
	return s.replace("[", "\u0001").replace("]", "[rb]").replace("\u0001", "[lb]")


func _on_submit(line: String) -> void:
	input.clear()
	focus.call_deferred()
	var trimmed := line.strip_edges()
	write_bb("[color=%s]%s[/color]%s" % [UiTheme.hex(UiTheme.accent), esc(prompt_label.text), esc(trimmed)])
	if trimmed.is_empty():
		return
	if _history.is_empty() or _history[_history.size() - 1] != trimmed:
		_history.append(trimmed)
	_history_index = _history.size()
	command_entered.emit(trimmed)


func _on_output_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		focus()


func _on_input_gui(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_UP:
			_history_step(-1)
			input.accept_event()
		KEY_DOWN:
			_history_step(1)
			input.accept_event()
		KEY_TAB:
			_complete()
			input.accept_event()
		KEY_L:
			if event.ctrl_pressed:
				clear()
				input.accept_event()


func _history_step(dir: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + dir, 0, _history.size())
	input.text = _history[_history_index] if _history_index < _history.size() else ""
	input.caret_column = input.text.length()


func _complete() -> void:
	if not completer.is_valid():
		return
	var text := input.text
	var options: PackedStringArray = completer.call(text)
	if options.is_empty():
		return
	var head := text.substr(0, text.rfind(" ") + 1)
	if options.size() == 1:
		input.text = head + options[0]
	else:
		var common := options[0]
		for o in options:
			while not o.begins_with(common):
				common = common.substr(0, common.length() - 1)
		input.text = head + common
		write("  ".join(options), UiTheme.DIM)
	input.caret_column = input.text.length()
