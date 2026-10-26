class_name Shell
extends RefCounted
## Interpreta os comandos digitados no terminal.

const COMMANDS := [
	["help", "lista os comandos"],
	["clear", "limpa a tela (Ctrl+L)"],
	["ls [dir]", "lista arquivos"],
	["cd <dir>", "muda de diretório"],
	["pwd", "mostra o diretório atual"],
	["cat <arquivo>", "mostra um arquivo"],
	["grep [-i] <termo> [arquivo]", "procura um termo (sem arquivo: em todos)"],
	["hosts", "lista as máquinas conhecidas"],
	["connect <host|ip>", "conecta numa máquina (ou clique no mapa)"],
	["mail [n]", "caixa de entrada"],
	["objetivos", "mostra o objetivo atual"],
	["responder <chave> <valor>", "responde um objetivo"],
	["decode <texto>", "decodifica base64"],
	["bloquear <ip>", "bloqueia um IP no firewall"],
	["isolar <host>", "isola uma máquina da rede"],
	["desativar <usuario>", "desativa uma conta"],
	["fichas [id]", "fichas ATT&CK desbloqueadas"],
	["arquivo [caso] [host:/arq]", "evidências de casos encerrados"],
	["tema <ciano|verde|roxo>", "muda a cor do terminal"],
	["whoami", "quem é você"],
]

var term: Terminal


func _init(t: Terminal) -> void:
	term = t


func prompt() -> String:
	var user := Game.player_name.to_lower().replace(" ", "")
	return "%s@%s:%s$" % [user, Game.host_id, Game.cwd]


func run(line: String) -> void:
	var args := tokenize(line)
	if args.is_empty():
		return
	var cmd := args[0].to_lower()
	args.remove_at(0)
	match cmd:
		"help", "ajuda": _help()
		"clear", "limpar": term.clear()
		"ls": _ls(args)
		"cd": _cd(args)
		"pwd": term.write(Game.cwd)
		"cat": _cat(args)
		"grep": _grep(args)
		"hosts": _hosts()
		"connect": _connect(args)
		"mail": _mail(args)
		"objetivos": _objectives()
		"responder": _answer(args)
		"decode": _decode(args)
		"bloquear": _block(args)
		"isolar": _isolate(args)
		"desativar": _disable(args)
		"fichas": _cards(args)
		"arquivo": _archive(args)
		"tema": _theme(args)
		"whoami": term.write("%s, analista do CSIRT" % Game.player_name)
		_: _unknown(line.strip_edges(), cmd)
	term.set_prompt(prompt())


## Quebra a linha em argumentos, respeitando aspas.
static func tokenize(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var quote := ""
	for ch in line:
		if quote.is_empty() and (ch == "\"" or ch == "'"):
			quote = ch
		elif ch == quote:
			quote = ""
		elif ch == " " and quote.is_empty():
			if not cur.is_empty():
				out.append(cur)
			cur = ""
		else:
			cur += ch
	if not cur.is_empty():
		out.append(cur)
	return out


func complete(text: String) -> PackedStringArray:
	var parts := text.split(" ")
	var last := parts[parts.size() - 1]
	var out := PackedStringArray()
	if parts.size() == 1:
		for c in COMMANDS:
			var name: String = c[0].get_slice(" ", 0)
			if name.begins_with(last):
				out.append(name)
		return out
	if parts[0] == "connect":
		for id in Game.hosts():
			if Game.revealed.has(id) and str(id).begins_with(last):
				out.append(id)
		return out
	var dir := last.substr(0, last.rfind("/") + 1)
	var base := last.substr(dir.length())
	var abs_dir := Game.resolve(dir if not dir.is_empty() else ".")
	for entry in Game.list_dir(abs_dir):
		if str(entry[0]).begins_with(base):
			out.append(dir + entry[0] + ("/" if entry[1] else ""))
	return out


func _help() -> void:
	term.write("comandos disponíveis:", UiTheme.accent)
	for c in COMMANDS:
		term.write_bb("  [color=%s]%s[/color]  %s" % [UiTheme.hex(UiTheme.accent), Terminal.esc(c[0].rpad(28)), c[1]])


func _ls(args: PackedStringArray) -> void:
	var path := Game.resolve(args[0] if args.size() > 0 else ".")
	if Game.is_file(path):
		term.write(path.get_file())
		return
	if not Game.is_dir(path):
		term.write("ls: diretório não encontrado: %s" % path, UiTheme.DANGER)
		return
	for entry in Game.list_dir(path):
		if entry[1]:
			term.write(entry[0] + "/", UiTheme.accent)
		else:
			term.write(entry[0])


func _cd(args: PackedStringArray) -> void:
	var path := Game.resolve(args[0] if args.size() > 0 else "/")
	if not Game.is_dir(path):
		term.write("cd: diretório não encontrado: %s" % path, UiTheme.DANGER)
		return
	Game.cwd = path


func _cat(args: PackedStringArray) -> void:
	if args.is_empty():
		term.write("uso: cat <arquivo>", UiTheme.DIM)
		return
	var path := Game.resolve(args[0])
	if not Game.is_file(path):
		term.write("cat: arquivo não encontrado: %s" % path, UiTheme.DANGER)
		return
	Game.record_evidence(path)
	for l in Game.read_file(path).split("\n"):
		term.write(l)
	Game.notify("cat", path)


func _grep(args: PackedStringArray) -> void:
	var ignore_case := args.has("-i")
	var rest := Array(args).filter(func(a): return a != "-i")
	if rest.is_empty():
		term.write("uso: grep [-i] <termo> [arquivo]", UiTheme.DIM)
		return
	var pattern: String = rest[0]
	var targets: Array = []
	if rest.size() > 1:
		var path := Game.resolve(rest[1])
		if not Game.is_file(path):
			term.write("grep: arquivo não encontrado: %s" % path, UiTheme.DANGER)
			return
		targets.append(path)
	else:
		targets = Game.files().keys()
		targets.sort()
	var hits := 0
	for path in targets:
		for l in Game.read_file(path).split("\n"):
			var idx := l.findn(pattern) if ignore_case else l.find(pattern)
			if idx < 0:
				continue
			hits += 1
			var prefix := "" if targets.size() == 1 else "[color=%s]%s:[/color] " % [UiTheme.hex(UiTheme.DIM), Terminal.esc(path)]
			term.write_bb(prefix + _highlight(l, pattern, ignore_case))
	if hits == 0:
		term.write("nenhuma ocorrência de \"%s\"" % pattern, UiTheme.DIM)
	Game.notify("grep", pattern)


func _highlight(line: String, pattern: String, ignore_case: bool) -> String:
	var out := ""
	var pos := 0
	var hl := UiTheme.hex(UiTheme.WARN)
	while true:
		var idx := line.findn(pattern, pos) if ignore_case else line.find(pattern, pos)
		if idx < 0 or pattern.is_empty():
			break
		out += Terminal.esc(line.substr(pos, idx - pos))
		out += "[color=%s][b]%s[/b][/color]" % [hl, Terminal.esc(line.substr(idx, pattern.length()))]
		pos = idx + pattern.length()
	return out + Terminal.esc(line.substr(pos))


func _hosts() -> void:
	for id in Game.hosts():
		if not Game.revealed.has(id):
			continue
		var h: Dictionary = Game.host(id)
		var mark := " <" if id == Game.host_id else ""
		term.write_bb("  [color=%s]%s[/color] %s %s%s" % [
			UiTheme.hex(UiTheme.accent), Terminal.esc(str(id).rpad(12)),
			str(h.get("ip", "")).rpad(16), Terminal.esc(str(h.get("nome", ""))), mark])


func _connect(args: PackedStringArray) -> void:
	if args.is_empty():
		term.write("uso: connect <host|ip>", UiTheme.DIM)
		return
	var id := Game.find_host(args[0])
	if id.is_empty():
		term.write("connect: host desconhecido: %s" % args[0], UiTheme.DANGER)
		return
	if Game.host(id).get("externo", false) and not Game.host(id).get("simulado", false):
		term.write("connect: %s é infraestrutura externa, fora do escopo do CSIRT." % id, UiTheme.WARN)
		term.write("registre o indicador no relatório e encaminhe às autoridades.", UiTheme.DIM)
		return
	if Game.host_state.get(id) == "isolado":
		term.write("connect: %s está isolado da rede" % id, UiTheme.WARN)
		return
	Game.connect_to(id)
	term.write("conectado a %s (%s)" % [Game.host(id).get("nome", id), Game.host(id).get("ip", "")], UiTheme.OK)
	Game.notify("connect", id)


func _mail(args: PackedStringArray) -> void:
	if Game.inbox.is_empty():
		term.write("caixa de entrada vazia", UiTheme.DIM)
		return
	if args.is_empty():
		for i in Game.inbox.size():
			var m: Dictionary = Game.inbox[i]
			var unread := "" if Game.read_mail.has(i) else "[color=%s]* [/color]" % UiTheme.hex(UiTheme.WARN)
			term.write_bb("  %s[url=mail %d][%d] %s[/url]  [color=%s]%s[/color]" % [
				unread, i + 1, i + 1, Terminal.esc(Game.fmt(m.get("assunto", ""))),
				UiTheme.hex(UiTheme.DIM), Terminal.esc(Game.fmt(m.get("de", "")))])
		return
	var n := args[0].to_int() - 1
	if n < 0 or n >= Game.inbox.size():
		term.write("mail: mensagem inexistente", UiTheme.DANGER)
		return
	show_mail(n)


func show_mail(n: int) -> void:
	var m: Dictionary = Game.inbox[n]
	Game.read_mail[n] = true
	term.write("De: " + Game.fmt(m.get("de", "")), UiTheme.DIM)
	term.write("Assunto: " + Game.fmt(m.get("assunto", "")), UiTheme.accent)
	term.write("")
	for l in Game.fmt(m.get("corpo", "")).split("\n"):
		term.write(l)
	Game.notify("mail", str(n + 1))


func _objectives() -> void:
	if Game.is_finished():
		term.write("todos os objetivos concluídos", UiTheme.OK)
		return
	var obj := Game.current_objective()
	term.write("objetivo %d/%d: %s" % [Game.objective_index + 1, Game.objectives().size(), Game.fmt(obj.get("texto", ""))], UiTheme.accent)
	if obj.has("dica"):
		term.write("dica: " + Game.fmt(obj["dica"]), UiTheme.DIM)


func _answer(args: PackedStringArray) -> void:
	var expected := Game.open_answer_key()
	if args.is_empty():
		term.write("uso: responder <chave> <valor>", UiTheme.DIM)
		if not expected.is_empty():
			term.write("pergunta aberta agora: responder %s <valor>" % expected, UiTheme.DIM)
		return
	var result := -1
	if args.size() >= 2:
		result = Game.answer(args[0], " ".join(args.slice(1)))
	# Iniciantes costumam esquecer a chave ("responder AURORA-7731"):
	# nesse caso, tudo o que veio depois do comando vira o valor.
	if result == -1 and not expected.is_empty():
		result = Game.answer(expected, " ".join(args))
	match result:
		1: term.write("resposta correta", UiTheme.OK)
		0: term.write("resposta incorreta, revise as evidências", UiTheme.DANGER)
		-2: term.write("conclusão sem evidências suficientes: consulte outras fontes do caso", UiTheme.WARN)
		_: term.write("nenhuma pergunta aberta agora", UiTheme.WARN)


## Um comando desconhecido que é exatamente a resposta da pergunta aberta
## é aceito como resposta; caso contrário, ensina a sintaxe.
func _unknown(line: String, cmd: String) -> void:
	var expected := Game.open_answer_key()
	if not expected.is_empty() and Game.answer_matches(line):
		term.write("entendido como resposta: responder %s %s" % [expected, line], UiTheme.DIM)
		_answer(PackedStringArray([expected, line]))
		return
	term.write("comando não encontrado: %s (digite help)" % cmd, UiTheme.DANGER)
	if not expected.is_empty():
		term.write("para responder o objetivo, use: responder %s <valor>" % expected, UiTheme.DIM)


func _decode(args: PackedStringArray) -> void:
	if args.is_empty():
		term.write("uso: decode <texto em base64>", UiTheme.DIM)
		return
	var text := Marshalls.base64_to_utf8("".join(args))
	if text.is_empty():
		term.write("decode: não parece base64 válido", UiTheme.DANGER)
		return
	term.write(text, UiTheme.WARN)
	Game.notify("decode", text)


## Ações de contenção. Uma ação que não resolve o objetivo atual
## custa tempo nas missões com cronômetro.
func _contain(command: String, arg: String, done_msg: String) -> void:
	term.write(done_msg, UiTheme.OK)
	var correct := Game.notify(command, arg)
	if not correct:
		Game.record_bad_containment()
	if not correct and Game.is_timed():
		var penalty := float(Game.mission.get("penalidade", 30))
		Game.penalize(penalty)
		term.write("ação desnecessária: a equipe perdeu %d segundos" % int(penalty), UiTheme.DANGER)


func _block(args: PackedStringArray) -> void:
	if args.is_empty() or args[0].split(".").size() != 4:
		term.write("uso: bloquear <ip>", UiTheme.DIM)
		return
	if Game.blocked_ips.has(args[0]):
		term.write("%s já está bloqueado" % args[0], UiTheme.DIM)
		return
	Game.blocked_ips[args[0]] = true
	_contain("bloquear", args[0], "regra criada no firewall: tráfego para %s bloqueado" % args[0])


func _isolate(args: PackedStringArray) -> void:
	if args.is_empty():
		term.write("uso: isolar <host>", UiTheme.DIM)
		return
	var id := Game.find_host(args[0])
	if id.is_empty():
		term.write("isolar: host desconhecido: %s" % args[0], UiTheme.DANGER)
		return
	if Game.host_state.get(id) == "isolado":
		term.write("%s já está isolado" % id, UiTheme.DIM)
		return
	Game.set_host_state(id, "isolado")
	_contain("isolar", id, "%s isolado da rede pelo EDR" % id)


func _disable(args: PackedStringArray) -> void:
	if args.is_empty():
		term.write("uso: desativar <usuario>", UiTheme.DIM)
		return
	var user := args[0].to_lower()
	if Game.disabled_users.has(user):
		term.write("a conta %s já está desativada" % user, UiTheme.DIM)
		return
	Game.disabled_users[user] = true
	_contain("desativar", user, "conta %s desativada e sessões encerradas" % user)


## Consulta evidências de casos já encerrados. Somente leitura.
##   arquivo                      lista os casos encerrados
##   arquivo <caso>               lista os arquivos do caso
##   arquivo <caso> <host:/arq>   mostra um arquivo
func _archive(args: PackedStringArray) -> void:
	var current := str(Game.mission.get("id", ""))
	if args.is_empty():
		var any := false
		for m in Game.list_missions():
			var id := str(m.get("id", ""))
			if id == current or not Game.completed_missions.has(id):
				continue
			any = true
			term.write_bb("  [url=arquivo %s][color=%s]%s[/color][/url]  %s" % [
				id, UiTheme.hex(UiTheme.accent), id, Terminal.esc(str(m.get("titulo", "")))])
		if not any:
			term.write("nenhum caso encerrado no arquivo ainda", UiTheme.DIM)
		return

	var m := Game.mission_by_id(args[0])
	if m.is_empty():
		term.write("arquivo: caso desconhecido: %s" % args[0], UiTheme.DANGER)
		return
	if not Game.completed_missions.has(args[0]):
		term.write("arquivo: o caso %s ainda não foi encerrado" % args[0], UiTheme.WARN)
		return

	if args.size() == 1:
		term.write(str(m.get("titulo", args[0])), UiTheme.accent)
		var hosts: Dictionary = m.get("hosts", {})
		for h in hosts:
			if hosts[h].get("externo", false):
				continue
			for path in hosts[h].get("arquivos", {}):
				var ref := "%s:%s" % [h, path]
				term.write_bb("  [url=arquivo %s %s]%s[/url]" % [args[0], ref, Terminal.esc(ref)])
		return

	var ref := args[1]
	var host_name := ref.get_slice(":", 0)
	var path := ref.substr(host_name.length() + 1)
	var text := Game.archive_file(args[0], host_name, path)
	if text.is_empty() or m.get("hosts", {}).get(host_name, {}).get("externo", false):
		term.write("arquivo: não encontrado: %s" % ref, UiTheme.DANGER)
		return
	term.write("[arquivo %s] %s" % [args[0], ref], UiTheme.DIM)
	for l in text.split("\n"):
		term.write(l)
	var key := "%s:%s" % [args[0], ref]
	Game.record_evidence_key(key)
	Game.notify("arquivo", key)


func _cards(args: PackedStringArray) -> void:
	if args.is_empty():
		if Game.unlocked_cards.is_empty():
			term.write("nenhuma ficha desbloqueada ainda", UiTheme.DIM)
		for id in Game.unlocked_cards:
			term.write_bb("  [url=fichas %s]%s[/url]  %s" % [id, id, Terminal.esc(Game.card(id).get("nome", ""))])
		return
	var id := args[0].to_upper()
	if not Game.unlocked_cards.has(id):
		term.write("ficha não desbloqueada: %s" % id, UiTheme.WARN)
		return
	var c := Game.card(id)
	term.write("%s  %s" % [id, c.get("nome", "")], UiTheme.accent)
	term.write(Game.fmt(c.get("descricao", "")))
	if c.has("defesa"):
		term.write("como se defender: " + Game.fmt(c["defesa"]), UiTheme.OK)
	if c.has("url"):
		term.write(c["url"], UiTheme.DIM)


func _theme(args: PackedStringArray) -> void:
	if args.is_empty() or not UiTheme.ACCENTS.has(args[0]):
		term.write("uso: tema <ciano|verde|roxo>", UiTheme.DIM)
		return
	Game.set_accent(args[0])
	Game.save_profile()
	term.write("tema alterado para %s" % args[0], UiTheme.accent)
