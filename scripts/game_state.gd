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
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	for id in cfg.get_section_keys("concluidas") if cfg.has_section("concluidas") else []:
		if cfg.get_value("concluidas", id, false):
			completed_missions[id] = true


func save_progress() -> void:
	var cfg := ConfigFile.new()
	for id in completed_missions:
		cfg.set_value("concluidas", id, true)
	var err := cfg.save(PROGRESS_PATH)
	if err != OK:
		push_warning("Falha ao salvar progresso: %s" % err)


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


## Resposta a um objetivo do tipo "resposta".
## Retorna 1 se acertou, 0 se errou e -1 se a chave não é a esperada agora.
func answer(key: String, value: String) -> int:
	var obj := current_objective()
	if obj.get("tipo", "") != "resposta" or _norm(key) != _norm(str(obj.get("chave", ""))):
		return -1
	var accepted = obj.get("valor", "")
	if typeof(accepted) != TYPE_ARRAY:
		accepted = [accepted]
	for v in accepted:
		if _norm(value) == _norm(str(v)):
			_complete_objective()
			return 1
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
		completed_missions[str(mission.get("id", ""))] = true
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
