extends Node
## Teste de fumaça: joga a missão de treinamento do começo ao fim pelo
## terminal e confere se ela termina. Rode com:
##   godot --headless --path . res://tests/playthrough.tscn

const STEPS := [
	"help",
	"ls",
	"cat leia-me.txt",
	"connect lab",
	"grep codigo /logs/treino.log",
	"responder codigo errado",
	"responder codigo AURORA-7731",
	"fichas ATT&CK",
	"mail",
	"mail 2",
	"connect arquivo",
	"cd relatorios",
	"cat modelo.txt",
	"ls /nao-existe",
	"comando-inexistente",
]

var _failed := false


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	Game.player_name = "Teste"
	Game.gender = Game.Gender.FEMININO
	var missions := Game.list_missions()
	_check(not missions.is_empty(), "há missões em res://missions")
	main._start_mission(missions[0])

	var term: Terminal = main._terminal
	for cmd in STEPS:
		term.run(cmd)
		await get_tree().process_frame

	_check(Game.is_finished(), "missão de treinamento concluída")
	_check(Game.unlocked_cards.has("ATT&CK"), "ficha desbloqueada")
	_check(Game.fmt("Bem-vind{o|a}, {nome}") == "Bem-vinda, Teste", "texto com gênero")
	print(term.output.get_parsed_text())
	await get_tree().create_timer(1.5).timeout
	print("RESULTADO: ", "FALHOU" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed = true
		push_error("falhou: " + what)
