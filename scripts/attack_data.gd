class_name AttackData
extends RefCounted
## Táticas do MITRE ATT&CK Enterprise (na ordem da matriz) e a qual tática
## cada técnica pertence. Uma ficha pode sobrescrever com "taticas": ["TA0008"].

const TACTICS := [
	["TA0043", "Reconhecimento"],
	["TA0042", "Desenvolvimento de recursos"],
	["TA0001", "Acesso inicial"],
	["TA0002", "Execução"],
	["TA0003", "Persistência"],
	["TA0004", "Escalada de privilégio"],
	["TA0005", "Evasão de defesa"],
	["TA0006", "Acesso a credenciais"],
	["TA0007", "Descoberta"],
	["TA0008", "Movimento lateral"],
	["TA0009", "Coleta"],
	["TA0011", "Comando e controle"],
	["TA0010", "Exfiltração"],
	["TA0040", "Impacto"],
]

## Técnica base (sem a subtécnica) para as táticas em que ela aparece.
const TECHNIQUE_TACTICS := {
	"T1595": ["TA0043"], "T1598": ["TA0043"], "T1589": ["TA0043"], "T1591": ["TA0043"],
	"T1583": ["TA0042"], "T1584": ["TA0042"], "T1585": ["TA0042"], "T1586": ["TA0042"], "T1588": ["TA0042"],
	"T1566": ["TA0001"], "T1190": ["TA0001"], "T1133": ["TA0001", "TA0003"], "T1199": ["TA0001"],
	"T1195": ["TA0001"], "T1189": ["TA0001"],
	"T1078": ["TA0001", "TA0003", "TA0004", "TA0005"],
	"T1059": ["TA0002"], "T1204": ["TA0002"], "T1047": ["TA0002"], "T1569": ["TA0002"],
	"T1072": ["TA0002", "TA0008"], "T1053": ["TA0002", "TA0003", "TA0004"],
	"T1547": ["TA0003", "TA0004"], "T1136": ["TA0003"], "T1098": ["TA0003", "TA0004"],
	"T1543": ["TA0003", "TA0004"], "T1505": ["TA0003"],
	"T1068": ["TA0004"], "T1055": ["TA0004", "TA0005"], "T1548": ["TA0004", "TA0005"],
	"T1027": ["TA0005"], "T1070": ["TA0005"], "T1562": ["TA0005"], "T1036": ["TA0005"],
	"T1112": ["TA0005"], "T1218": ["TA0005"], "T1140": ["TA0005"],
	"T1003": ["TA0006"], "T1110": ["TA0006"], "T1552": ["TA0006"], "T1555": ["TA0006"],
	"T1558": ["TA0006"], "T1621": ["TA0006"], "T1056": ["TA0006", "TA0009"], "T1539": ["TA0006"],
	"T1528": ["TA0006"],
	"T1082": ["TA0007"], "T1083": ["TA0007"], "T1087": ["TA0007"], "T1018": ["TA0007"],
	"T1046": ["TA0007"], "T1069": ["TA0007"], "T1057": ["TA0007"], "T1016": ["TA0007"],
	"T1021": ["TA0008"], "T1570": ["TA0008"], "T1210": ["TA0008"], "T1550": ["TA0005", "TA0008"],
	"T1005": ["TA0009"], "T1039": ["TA0009"], "T1074": ["TA0009"], "T1114": ["TA0009"],
	"T1119": ["TA0009"], "T1113": ["TA0009"], "T1213": ["TA0009"], "T1530": ["TA0009"],
	"T1560": ["TA0009"],
	"T1071": ["TA0011"], "T1105": ["TA0011"], "T1219": ["TA0011"], "T1090": ["TA0011"],
	"T1572": ["TA0011"], "T1573": ["TA0011"], "T1102": ["TA0011"], "T1132": ["TA0011"],
	"T1041": ["TA0010"], "T1567": ["TA0010"], "T1048": ["TA0010"], "T1020": ["TA0010"],
	"T1486": ["TA0040"], "T1490": ["TA0040"], "T1489": ["TA0040"], "T1485": ["TA0040"],
	"T1565": ["TA0040"], "T1491": ["TA0040"], "T1657": ["TA0040"], "T1499": ["TA0040"],
}


static func is_technique(id: String) -> bool:
	return id.begins_with("T") and id.substr(1, 4).is_valid_int()


static func tactics_for(id: String, card: Dictionary = {}) -> Array:
	if card.has("taticas"):
		return card["taticas"]
	return TECHNIQUE_TACTICS.get(id.get_slice(".", 0), [])


static func tactic_name(tactic_id: String) -> String:
	for t in TACTICS:
		if t[0] == tactic_id:
			return t[1]
	return tactic_id
