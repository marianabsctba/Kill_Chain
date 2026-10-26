extends Node
## Regressão da campanha: verifica fluxo sequencial, fontes e pontuação.
## Execução: godot --headless --path . res://tests/campanha.tscn

var failures: Array[String] = []

func _ready() -> void:
	Game.player_name = "Teste CSIRT"
	Game.completed_missions.clear()
	Game.best_scores.clear()
	var cases := Game.list_missions()
	_assert(cases.size() >= 6, "Existem pelo menos seis casos")
	for m in cases:
		var id := str(m.get("id", ""))
		if not Game.is_mission_unlocked(m):
			_assert(false, "Missão desbloqueada na ordem correta: " + id)
			continue
		Game.start_mission(m)
		_assert(Game.running, "Missão iniciou: " + id)
		for obj in m.get("objetivos", []):
			var objective_id := str(obj.get("id", ""))
			for entry in obj.get("evidencias", []):
				var bits := str(entry).split(":", false, 1)
				_assert(bits.size() == 2, "Formato de evidência: " + str(entry))
				if bits.size() != 2:
					continue
				var host := bits[0]
				var path := bits[1]
				_assert(Game.revealed.has(host), "Host revelado em " + id + "/" + objective_id + ": " + host)
				_assert(Game.host(host).get("arquivos", {}).has(path), "Arquivo existente: " + str(entry))
				if Game.revealed.has(host):
					Game.connect_to(host)
					Game.record_evidence(path)
			var kind := str(obj.get("tipo", ""))
			var ok := false
			match kind:
				"resposta":
					var accepted = obj.get("valor", "")
					var value := str(accepted[0]) if typeof(accepted) == TYPE_ARRAY else str(accepted)
					ok = Game.answer(str(obj.get("chave", "")), value) == 1
				"ler":
					var host := str(obj.get("host", ""))
					var path := str(obj.get("arquivo", ""))
					_assert(Game.revealed.has(host), "Host acessível: " + id + "/" + objective_id)
					_assert(Game.host(host).get("arquivos", {}).has(path), "Arquivo do objetivo existe: " + path)
					Game.connect_to(host)
					Game.record_evidence(path)
					ok = Game.notify("cat", path)
				"comando":
					var command := str(obj.get("comando", ""))
					var target := str(obj.get("alvo", ""))
					if command == "connect":
						_assert(Game.revealed.has(target), "Alvo revelado para conexão: " + target)
						_assert(not Game.host(target).get("externo", false) or Game.host(target).get("simulado", false), "Acesso externo somente simulado: " + target)
						Game.connect_to(target)
					ok = Game.notify(command, target)
				_:
					_assert(false, "Tipo de objetivo desconhecido: " + kind)
			_assert(ok, "Concluído: " + id + "/" + objective_id)
		_assert(Game.is_finished(), "Caso encerrado: " + id)
		_assert(Game.completed_missions.has(id), "Progresso registrado: " + id)
		_assert(Game.score_result >= 0 and Game.score_result <= 1000, "Pontuação válida: " + id)
		for card_id in Game.unlocked_cards:
			_assert(m.get("fichas", {}).has(card_id), "Ficha ATT&CK existente: " + str(card_id))
	if failures.is_empty():
		print("CAMPANHA: OK, %d casos validados." % cases.size())
	else:
		for problem in failures:
			push_error(problem)
		print("CAMPANHA: FALHOU, %d erros." % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
