extends Node

var combatentes_ativos: Array[CombatEntity] = []

func registrar_combatente(entidade: CombatEntity) -> void:
	combatentes_ativos.append(entidade)

# Calcula a agilidade efetiva usando a fórmula assintótica de modificadores
func calcular_agilidade_efetiva(entidade: CombatEntity) -> float:
	var base = entidade.base_data.agilidade_base
	var multiplicador_buff = pow(1.1, entidade.buffs)
	var multiplicador_debuff = pow(0.9, entidade.debuffs)
	
	var agilidade_final = base * multiplicador_buff * multiplicador_debuff
	
	if entidade.is_exausto:
		agilidade_final *= 0.5 # Penalidade severa por exaustão
		
	return max(1.0, agilidade_final)

# Motor de Saltos de Tempo
func avancar_timeline() -> CombatEntity:
	var menor_salto: float = INF
	var proxima_entidade: CombatEntity = null
	
	# 1. Determina o custo de espera (Valor_Atual / Agilidade) para encontrar o menor salto
	for entidade in combatentes_ativos:
		var agilidade_efetiva = calcular_agilidade_efetiva(entidade)
		var tempo_relativo = entidade.action_value / agilidade_efetiva
		
		if tempo_relativo < menor_salto:
			menor_salto = tempo_relativo
			proxima_entidade = entidade
			
	# 2. Atualização em lote: avança o relógio de todos simultaneamente
	for entidade in combatentes_ativos:
		var agilidade_efetiva = calcular_agilidade_efetiva(entidade)
		entidade.action_value -= (menor_salto * agilidade_efetiva)
		
	# A entidade com action_value zerado ganha a prioridade
	return proxima_entidade

# Aplica repulsão na fila com achatamento logarítmico para impedir stunlocks infinitos
func aplicar_knockback(alvo: CombatEntity, forca_bruta: float) -> void:
	alvo.knockback_stacks += 1
	var denominador = log(2.0 + alvo.knockback_stacks) / log(2.0) # Base 2 log
	var recuo_efetivo = forca_bruta / denominador
	
	alvo.action_value += recuo_efetivo
