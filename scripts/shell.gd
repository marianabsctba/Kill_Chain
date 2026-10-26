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
	["fichas [id]", "fichas ATT&CK desbloqueadas"],
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
		"fichas": _cards(args)
		"tema": _theme(args)
		"whoami": term.write("%s, analista do CSIRT" % Game.player_name)
		_: term.write("comando não encontrado: %s (digite help)" % cmd, UiTheme.DANGER)
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
	if args.size() < 2:
		term.write("uso: responder <chave> <valor>", UiTheme.DIM)
		return
	var value := " ".join(args.slice(1))
	match Game.answer(args[0], value):
		1: term.write("resposta correta", UiTheme.OK)
		0: term.write("resposta incorreta, revise as evidências", UiTheme.DANGER)
		_: term.write("nenhuma pergunta aberta com a chave \"%s\"" % args[0], UiTheme.WARN)


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
