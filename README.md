# Kill Chain

Jogo educativo de defesa cibernética, em português, feito em Godot 4. Você é analista de um CSIRT, investiga incidentes pelo terminal e aprende o MITRE ATT&CK caso a caso.

## Como rodar

1. Instale a [Godot 4.7](https://godotengine.org/download) (versão padrão, não precisa da .NET).
2. Abra a Godot, clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Aperte **F5**.

Atalhos no jogo: **F2** liga e desliga o efeito CRT, **F11** alterna tela cheia, **Tab** completa comandos, **setas** navegam no histórico.

## Estrutura

```
scenes/main.tscn        cena principal
scripts/main.gd         telas: boot, perfil, menu, mesa de trabalho
scripts/game_state.gd   estado global (autoload Game): perfil, missão, arquivos, objetivos
scripts/shell.gd        comandos do terminal
scripts/terminal.gd     terminal com digitação animada, histórico e autocompletar
scripts/net_map.gd      mapa da rede animado
scripts/ui_theme.gd     paleta e tema visual
shaders/crt.gdshader    efeito de monitor CRT
missions/*.json         casos jogáveis
tests/                  teste automático e gerador de prints
```

## Missões

Cada caso é um arquivo JSON em `missions/`, carregado automaticamente no menu. Os textos aceitam:

- `{nome}`: nome do jogador
- `{o|a}`: forma masculina ou feminina, conforme o personagem escolhido (ex.: `Bem-vind{o|a}`)

Tipos de objetivo:

| tipo | conclui quando | campos |
|---|---|---|
| `ler` | o jogador abre um arquivo com `cat` | `host`, `arquivo` |
| `comando` | o jogador roda um comando | `comando`, `alvo` (opcional) |
| `resposta` | o jogador digita `responder <chave> <valor>` | `chave`, `valor` (texto ou lista) |

Todo objetivo pode ter `dica`, `fichas` (fichas ATT&CK desbloqueadas), `revela` (hosts que aparecem no mapa) e `estados` (muda a cor de hosts: `normal`, `alerta`, `comprometido`, `isolado`, `seguro`). E-mails chegam no início (`"quando": "inicio"`) ou ao concluir um objetivo (`"quando": "<id do objetivo>"`).

Veja `missions/00_treinamento.json` como exemplo completo.

## Testes

```
godot --headless --path . res://tests/playthrough.tscn
```

Joga o treinamento inteiro pelo terminal e retorna erro se algo quebrar.
