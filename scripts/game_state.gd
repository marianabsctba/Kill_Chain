extends Node
## Estado global (autoload "Game"): perfil do jogador, missão atual,
## sistema de arquivos virtual de cada host, caixa de entrada e objetivos.

signal mission_started
signal mission_finished
signal mission_failed
signal objective_completed(objective: Dictionary)
signal mail_received(mail: Dictionary)
signal host_changed
signal network_changed
signal accent_changed

enum Gender { MASCULINO, FEMININO }

const PROFILE_PATH := "user://perfil.cfg"
const PROGRESS_PATH := "user://progresso.cfg"
const MISSIONS_DIR := "res://missions"

var completed_missions: Dictionary = {}
var best_scores: Dictionary = {}
var evidence_seen: Dictionary = {}
var wrong_answers := 0
var wrong_containment := 0
var score_result := 0

var player_name := ""
var gender: int = Gender.FEMININO
var accent_name := "ciano"

var mission: Dictionary = {}
var host_id := ""
var cwd := "/"
var revealed := {}
var host_state := {}
var inbox: Array = []
var read_mail := {}
var objective_index := 0
var unlocked_cards: Array = []
var blocked_ips := {}
var disabled_users := {}

## Cronômetro da missão em segundos (0 = sem limite). Só corre com running.
var time_left := 0.0
var running := false

var _gender_re := RegEx.create_from_string("\\{([^{}|]*)\\|([^{}|]*)\\}")


func _ready() -> void:
	load_profile()
	load_progress()


func _process(delta: float) -> void:
	if not running or time_left <= 0.0:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		running = false
		mission_failed.emit()


func is_timed() -> bool:
	return float(mission.get("tempo", 0)) > 0.0


## Tira segundos do cronômetro como punição por uma ação errada.
func penalize(seconds: float) -> void:
	if running and is_timed():
		time_left = maxf(time_left - seconds, 0.01)


# Perfil

func has_profile() -> bool:
	return not player_name.is_empty()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("perfil", "nome", player_name)
	cfg.set_value("perfil", "genero", gender)
	cfg.set_value("perfil", "tema", accent_name)
	cfg.save(PROFILE_PATH)


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	player_name = cfg.get_value("perfil", "nome", "")
	gender = cfg.get_value("perfil", "genero", Gender.FEMININO)
	set_accent(cfg.get_value("perfil", "tema", "ciano"))


func set_accent(name: String) -> void:
	if not UiTheme.ACCENTS.has(name):
		return
	accent_name = name
	UiTheme.set_accent(name)
	accent_changed.emit()


## Escolhe a forma masculina ou feminina conforme o perfil.
func g(masc: String, fem: String) -> String:
	return masc if gender == Gender.MASCULINO else fem


## Aplica o perfil a um texto de missão: {nome} vira o nome do jogador e
## {o|a} vira a forma masculina ou feminina.
func fmt(text: String) -> String:
	var src := text.replace("{nome}", player_name)
	var out := ""
	var pos := 0
	for m in _gender_re.search_all(src):
		out += src.substr(pos, m.get_start() - pos)
		out += m.get_string(1) if gender == Gender.MASCULINO else m.get_string(2)
		pos = m.get_end()
	return out + src.substr(pos)


# Progresso salvo localmente

func load_progress() -> void:
	completed_missions.clear()
	best_scores.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	if cfg.has_section("concluidas"):
		for id in cfg.get_section_keys("concluidas"):
			if cfg.get_value("concluidas", id, false):
				completed_missions[id] = true
	if cfg.has_section("recordes"):
		for id in cfg.get_section_keys("recordes"):
			best_scores[id] = int(cfg.get_value("recordes", id, 0))


func save_progress() -> void:
	var cfg := ConfigFile.new()
	for id in completed_missions:
		cfg.set_value("concluidas", id, true)
	for id in best_scores:
		cfg.set_value("recordes", id, best_scores[id])
	var err := cfg.save(PROGRESS_PATH)
	if err != OK:
		push_warning("Falha ao salvar progresso: %s" % err)


# Temporada

## true logo depois que o último caso pendente da temporada é concluído.
var season_just_completed := false


func season_complete() -> bool:
	var missions := list_missions()
	if missions.is_empty():
		return false
	for m in missions:
		if not completed_missions.has(str(m.get("id", ""))):
			return false
	return true


func season_score() -> int:
	var total := 0
	for id in best_scores:
		total += int(best_scores[id])
	return total


## Técnicas ATT&CK da temporada: {id: {"card": ficha, "found": bool}}.
## Uma técnica conta como descoberta quando algum caso que a ensina foi concluído.
func season_techniques() -> Dictionary:
	var out := {}
	for m in list_missions():
		var done := completed_missions.has(str(m.get("id", "")))
		var cards: Dictionary = m.get("fichas", {})
		for obj in m.get("objetivos", []):
			for c in obj.get("fichas", []):
				var id := str(c)
				if not AttackData.is_technique(id) or not cards.has(id):
					continue
				if not out.has(id):
					out[id] = {"card": cards[id], "found": false}
				if done:
					out[id]["found"] = true
	return out


func mission_by_id(id: String) -> Dictionary:
	for m in list_missions():
		if str(m.get("id", "")) == id:
			return m
	return {}


## Lê um arquivo de um caso já encerrado (comando arquivo).
func archive_file(mission_id: String, host_name: String, path: String) -> String:
	var m := mission_by_id(mission_id)
	var content = m.get("hosts", {}).get(host_name, {}).get("arquivos", {}).get(path, null)
	if content == null:
		return ""
	if typeof(content) == TYPE_ARRAY:
		return "\n".join(PackedStringArray(content))
	return fmt(str(content))


func record_evidence_key(key: String) -> void:
	if running:
		evidence_seen[key] = true


func is_mission_unlocked(m: Dictionary) -> bool:
	var required := str(m.get("requer", ""))
	return required.is_empty() or completed_missions.has(required)


# Missões

func list_missions() -> Array:
	var result: Array = []
	for f in DirAccess.get_files_at(MISSIONS_DIR):
		if f.ends_with(".json"):
			var m := load_mission_file(MISSIONS_DIR.path_join(f))
			if not m.is_empty():
				result.append(m)
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result


func load_mission_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Missão inválida: %s" % path)
		return {}
	return data


func start_mission(m: Dictionary) -> void:
	if not is_mission_unlocked(m):
		push_warning("Missão bloqueada: " + str(m.get("id", "")))
		return
	mission = m
	revealed.clear()
	host_state.clear()
	inbox.clear()
	read_mail.clear()
	unlocked_cards.clear()
	blocked_ips.clear()
	disabled_users.clear()
	objective_index = 0
	evidence_seen.clear()
	wrong_answers = 0
	wrong_containment = 0
	score_result = 0
	time_left = float(mission.get("tempo", 0))
	running = true
	for id in hosts():
		var h: Dictionary = hosts()[id]
		host_state[id] = h.get("estado", "normal")
		if not h.get("oculto", false):
			revealed[id] = true
	host_id = mission.get("inicio", "")
	cwd = "/"
	mission_started.emit()
	_deliver_mail("inicio")


func hosts() -> Dictionary:
	return mission.get("hosts", {})


func host(id: String) -> Dictionary:
	return hosts().get(id, {})


## Encontra um host visível pelo id ou pelo IP.
func find_host(name_or_ip: String) -> String:
	for id in hosts():
		if not revealed.has(id):
			continue
		if id == name_or_ip or str(host(id).get("ip", "")) == name_or_ip:
			return id
	return ""


func connect_to(id: String) -> void:
	host_id = id
	cwd = "/"
	host_changed.emit()


func set_host_state(id: String, state: String) -> void:
	host_state[id] = state
	network_changed.emit()


func card(id: String) -> Dictionary:
	return mission.get("fichas", {}).get(id, {})


# Objetivos

func objectives() -> Array:
	return mission.get("objetivos", [])


func current_objective() -> Dictionary:
	var objs := objectives()
	return objs[objective_index] if objective_index < objs.size() else {}


func is_finished() -> bool:
	return not objectives().is_empty() and objective_index >= objectives().size()


## Chamado pelo terminal a cada comando bem-sucedido. Avança o objetivo
## atual quando ele é do tipo "comando" ou "ler" e bate com o evento.
## Retorna true se o comando concluiu o objetivo.
func record_evidence(path: String) -> void:
	if running:
		evidence_seen["%s:%s" % [host_id, path]] = true

func record_bad_containment() -> void:
	if running:
		wrong_containment += 1

func missing_evidence(obj: Dictionary) -> Array:
	var missing: Array = []
	for entry in obj.get("evidencias", []):
		if not evidence_seen.has(str(entry)):
			missing.append(entry)
	return missing

func calculate_score() -> int:
	var points := 600 if is_finished() else 0
	points += mini(evidence_seen.size() * 25, 200)
	points += int(200.0 * clampf(time_left / maxf(float(mission.get("tempo", 1)), 1.0), 0.0, 1.0)) if is_timed() else 200
	return maxi(0, points - wrong_answers * 35 - wrong_containment * 75)

func score_rank(points: int) -> String:
	if points >= 900:
		return "S"
	if points >= 750:
		return "A"
	if points >= 600:
		return "B"
	return "C"

func notify(command: String, arg := "") -> bool:
	var obj := current_objective()
	if obj.is_empty():
		return false
	var ok := false
	match obj.get("tipo", ""):
		"comando":
			ok = command == obj.get("comando", "") \
				and (not obj.has("alvo") or _norm(arg) == _norm(str(obj["alvo"])))
		"ler":
			ok = command == "cat" \
				and host_id == obj.get("host", host_id) \
				and arg == obj.get("arquivo", "")
	if ok:
		_complete_objective()
	return ok


## Chave da pergunta aberta agora, ou "" se o objetivo atual não pede resposta.
func open_answer_key() -> String:
	var obj := current_objective()
	return str(obj.get("chave", "")) if obj.get("tipo", "") == "resposta" else ""


## Confere se o valor responde a pergunta aberta, sem contar erro.
func answer_matches(value: String) -> bool:
	var accepted = current_objective().get("valor", "")
	if typeof(accepted) != TYPE_ARRAY:
		accepted = [accepted]
	for v in accepted:
		if _norm(value) == _norm(str(v)):
			return true
	return false


## Resposta a um objetivo do tipo "resposta".
## Retorna 1 se acertou, 0 se errou e -1 se a chave não é a esperada agora.
func answer(key: String, value: String) -> int:
	var obj := current_objective()
	if obj.get("tipo", "") != "resposta" or _norm(key) != _norm(str(obj.get("chave", ""))):
		return -1
	if not missing_evidence(obj).is_empty():
		return -2
	var accepted = obj.get("valor", "")
	if typeof(accepted) != TYPE_ARRAY:
		accepted = [accepted]
	for v in accepted:
		if _norm(value) == _norm(str(v)):
			_complete_objective()
			return 1
	wrong_answers += 1
	return 0


func _complete_objective() -> void:
	var obj := current_objective()
	objective_index += 1
	for c in obj.get("fichas", []):
		if not unlocked_cards.has(c):
			unlocked_cards.append(c)
	for h in obj.get("revela", []):
		revealed[h] = true
	var states: Dictionary = obj.get("estados", {})
	for h in states:
		host_state[h] = states[h]
	objective_completed.emit(obj)
	network_changed.emit()
	_deliver_mail(str(obj.get("id", "")))
	if is_finished():
		running = false
		var id := str(mission.get("id", ""))
		var was_complete := season_complete()
		completed_missions[id] = true
		season_just_completed = not was_complete and season_complete()
		score_result = calculate_score()
		best_scores[id] = maxi(int(best_scores.get(id, 0)), score_result)
		save_progress()
		mission_finished.emit()


func _deliver_mail(trigger: String) -> void:
	for mail in mission.get("emails", []):
		if str(mail.get("quando", "inicio")) == trigger:
			inbox.append(mail)
			mail_received.emit(mail)


func _norm(s: String) -> String:
	return s.strip_edges().to_lower()


# Sistema de arquivos virtual do host atual

func files() -> Dictionary:
	return host(host_id).get("arquivos", {})


func resolve(path: String) -> String:
	var full := path if path.begins_with("/") else cwd.path_join(path)
	var parts := PackedStringArray()
	for s in full.split("/", false):
		if s == ".":
			continue
		if s == "..":
			if parts.size() > 0:
				parts.remove_at(parts.size() - 1)
			continue
		parts.append(s)
	return "/" + "/".join(parts)


func is_file(path: String) -> bool:
	return files().has(path)


func is_dir(path: String) -> bool:
	if path == "/":
		return true
	var prefix := path + "/"
	for k in files():
		if str(k).begins_with(prefix):
			return true
	return false


## Lista o conteúdo de um diretório como [[nome, eh_diretorio], ...].
func list_dir(path: String) -> Array:
	var prefix := "/" if path == "/" else path + "/"
	var seen := {}
	var out: Array = []
	for k in files():
		var key := str(k)
		if not key.begins_with(prefix):
			continue
		var rest := key.substr(prefix.length())
		var name := rest.get_slice("/", 0)
		if seen.has(name):
			continue
		seen[name] = true
		out.append([name, rest.contains("/")])
	out.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	return out


func read_file(path: String) -> String:
	var content = files().get(path, "")
	if typeof(content) == TYPE_ARRAY:
		return "\n".join(PackedStringArray(content))
	return fmt(str(content))
