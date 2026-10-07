extends Node
class_name BattleExecutor

var timeline_ref: Node # Referência ao TimelineManager

func aplicar_pilha_stagger(alvo: CombatEntity, quantidade: int) -> void:
	# Lógica a ser expandida: compara a quantidade de pilhas com a Estatura do alvo
	# (Pequeno, Médio, Grande) para determinar se entra no estado Atordoado ou Derrubado.
	pass

# No BattleExecutor:
func executar_projecao(atacante: CombatEntity, alvo: CombatEntity, proj: Dictionary, habilidade: SkillData) -> void:
	# 1. Aplicação de Morte Instantânea (O Julgamento)
	if proj.executar_morte_imediata:
		alvo.aplicar_dano(alvo.hp_atual)
		return

	# 2. Dano Final com Intensificadores e Dano Extra
	var mult = 1.0 + (proj.intensificadores_percent / 100.0)
	var dano_final = int(proj.dano_base * mult) + proj.dano_extra_puro
	alvo.aplicar_dano(dano_final)

	# 3. Knockback e Stagger (Recuperados da função antiga)
	if proj.forca_knockback_final > 0.0 and timeline_ref:
		timeline_ref.aplicar_knockback(alvo, proj.forca_knockback_final)
		
	if proj.intensificadores_percent > 0:
		# Modifica a aflição de ATORDOADO/DERRUBADO usando a nova função do CombatEntity
		aplicar_pilha_stagger(alvo, habilidade.dano_postura)

	# 4. Retaliações no Atacante
	if proj.dano_refletido_atacante > 0:
		atacante.aplicar_dano(proj.dano_refletido_atacante)
	for af in proj.alteracoes_aflicoes_atacante:
		atacante.modificar_pilhas_aflicao(af, proj.alteracoes_aflicoes_atacante[af])

	# 5. Atualização de Aflições no Alvo (deltas positivos ou negativos)
	for af in proj.alteracoes_aflicoes_alvo:
		alvo.modificar_pilhas_aflicao(af, proj.alteracoes_aflicoes_alvo[af])
