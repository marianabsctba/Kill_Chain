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
				var ref := str(entry)
				var first_colon := ref.find(":")
				_assert(first_colon > 0, "Formato de evidência: " + ref)
				if first_colon < 0:
					continue
				var first := ref.substr(0, first_colon)
				var rest := ref.substr(first_colon + 1)
				if Game.hosts().has(first):
					_assert(Game.revealed.has(first), "Host revelado: " + first)
					_assert(Game.host(first).get("arquivos", {}).has(rest), "Arquivo existente: " + ref)
					if Game.revealed.has(first):
						Game.connect_to(first)
						Game.record_evidence(rest)
				else:
					var archived := Game.mission_by_id(first)
					var colon := rest.find(":")
					_assert(not archived.is_empty() and colon > 0, "Referência de arquivo válida: " + ref)
					if colon > 0:
						var source_host := rest.substr(0, colon)
						var source_path := rest.substr(colon + 1)
						_assert(Game.completed_missions.has(first), "Caso arquivado concluído: " + first)
						_assert(archived.get("hosts", {}).get(source_host, {}).get("arquivos", {}).has(source_path), "Prova arquivada existente: " + ref)
						Game.record_evidence_key(ref)
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
					if command == "arquivo":
						var colon := target.find(":")
						var mission_id := target.substr(0, colon)
						var host_ref := target.substr(colon + 1)
						var archived := Game.mission_by_id(mission_id)
						var part := host_ref.find(":")
						if part >= 0:
							_assert(archived.get("hosts", {}).get(host_ref.substr(0, part), {}).get("arquivos", {}).has(host_ref.substr(part + 1)), "Arquivo do caso anterior existe: " + target)
						Game.record_evidence_key(target)
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
