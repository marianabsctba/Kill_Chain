extends Node
## Gera prints das telas principais em user://screenshots (precisa de janela,
## não roda em --headless):
##   godot --path . res://tests/screenshots.tscn

var _main: Node


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	await _wait(2.0)
	await _shot("1_boot")

	_main._show_profile()
	await _wait(0.6)
	await _shot("2_perfil")

	Game.player_name = "Mari"
	Game.gender = Game.Gender.FEMININO
	_main._show_menu()
	await _wait(0.6)
	await _shot("3_menu")

	_main._start_mission(Game.list_missions()[0])
	var term: Terminal = _main._terminal
	for cmd in ["cat leia-me.txt", "connect lab", "grep codigo /logs/treino.log"]:
		term.run(cmd)
		await _wait(0.3)
	await _wait(1.2)
	await _shot("4_mesa")
	print("prints em ", ProjectSettings.globalize_path("user://screenshots"))
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://screenshots/%s.png" % name)
