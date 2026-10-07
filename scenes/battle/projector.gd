extends Node
class_name BattleProjector

const AFLICOES_CONSUMIVEIS: Array[CombatEntity.Aflicao] = [
	CombatEntity.Aflicao.MOLHADO, CombatEntity.Aflicao.LAMACADO, 
	CombatEntity.Aflicao.EMPOEIRADO, CombatEntity.Aflicao.QUEIMADURA, 
	CombatEntity.Aflicao.ELETRO_ATIVA, CombatEntity.Aflicao.ELETRO_PASSIVA, 
	CombatEntity.Aflicao.INFECCAO
]

func projetar_ataque(atacante: CombatEntity, alvo: CombatEntity, habilidade: SkillData) -> Dictionary:
	# Inicialização explícita e tipada de todos os campos do contrato
	var projecao: Dictionary = {
		"dano_base": 0,
		"intensificadores_percent": 0, # Soma de bônus (+50% por intensificador)
		"is_critico": false,
		"is_forte": false,
		"is_tecnico": false,
		"forca_knockback_final": habilidade.forca_knockback,
		"dano_extra_puro": 0,
		"dano_refletido_atacante": 0,
		"executar_morte_imediata": false,
		"alteracoes_aflicoes_alvo": {},     # Chave: CombatEntity.Aflicao, Valor: int (delta)
		"alteracoes_aflicoes_atacante": {}  # Chave: CombatEntity.Aflicao, Valor: int (delta)
	}
	
	# Cálculo de Dano Base em Inteiros
	projecao.dano_base = int((atacante.base_data.hp_maximo * 0.1) * habilidade.multiplicador_dano)
	
	# 1. Filtro de Fraquezas (Intensificador Forte) e Resistências
	if habilidade.elemento in alvo.base_data.fraquezas:
		projecao.is_forte = true
		projecao.intensificadores_percent += 50
	elif habilidade.elemento in alvo.base_data.resistencias:
		projecao.dano_base = int(projecao.dano_base * 0.5)
		
	# 2. Teste de Crítico em Inteiros: randi_range(1, vida_atual) <= dano
	if alvo.hp_atual > 0:
		if projecao.dano_base >= alvo.hp_atual or randi_range(1, alvo.hp_atual) <= projecao.dano_base:
			projecao.is_critico = true
			projecao.intensificadores_percent += 50
			
	# 3. Avaliação da Matriz de Reações
	_avaliar_matriz_reacoes(atacante, alvo, habilidade, projecao)
	
	return projecao

func _avaliar_matriz_reacoes(atacante: CombatEntity, alvo: CombatEntity, habilidade: SkillData, projecao: Dictionary) -> void:
	var el = habilidade.elemento
	var Af = CombatEntity.Aflicao
	
	# --- CORRUPÇÃO ELEMENTAL GENÉRICA (Qualquer elemento exceto Físico/Trevas vs Ruína) ---
	if el != CombatEntity.Elemento.FISICO and el != CombatEntity.Elemento.TREVAS and alvo.has_aflicao(Af.RUINA):
		projecao.is_tecnico = true
		projecao.intensificadores_percent += 50
		
		var pilhas_ruina = alvo.aflicoes[Af.RUINA]
		projecao.dano_extra_puro += pilhas_ruina # Dano Extra igual às pilhas de Ruína[cite: 13]
		projecao.alteracoes_aflicoes_alvo[Af.RUINA] = -pilhas_ruina # Consome a Ruína[cite: 13]
		
		# Dissolve a Ruína e mapeia para a aflição do elemento atacante[cite: 13]
		var aflicao_convertida = -1
		match el:
			CombatEntity.Elemento.FOGO:
				aflicao_convertida = Af.QUEIMADURA
			CombatEntity.Elemento.RAIO:
				aflicao_convertida = Af.ELETRO_ATIVA # Aplicação padrão de impacto
			CombatEntity.Elemento.BIOLOGICO:
				aflicao_convertida = Af.INFECCAO
			CombatEntity.Elemento.AGUA:
				aflicao_convertida = Af.MOLHADO
			CombatEntity.Elemento.TERRA:
				aflicao_convertida = Af.EMPOEIRADO
				
		if aflicao_convertida != -1:
			projecao.alteracoes_aflicoes_alvo[aflicao_convertida] = projecao.alteracoes_aflicoes_alvo.get(aflicao_convertida, 0) + pilhas_ruina
	
	# --- ELEMENTO FÍSICO ---
	if el == CombatEntity.Elemento.FISICO:
		if alvo.has_aflicao(Af.MOLHADO) or alvo.has_aflicao(Af.LAMACADO):
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			projecao.forca_knockback_final *= 1.5
		elif alvo.has_aflicao(Af.QUEIMADURA):
			var pilhas_alvo = alvo.aflicoes[Af.QUEIMADURA]
			var pilhas_roubadas = maxi(1, int(pilhas_alvo * 0.2))
			projecao.alteracoes_aflicoes_atacante[Af.QUEIMADURA] = pilhas_roubadas
			projecao.dano_refletido_atacante = pilhas_roubadas
		elif alvo.has_aflicao(Af.EMPOEIRADO):
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			projecao.dano_extra_puro += alvo.aflicoes[Af.EMPOEIRADO]
		elif alvo.has_aflicao(Af.RUINA):
			projecao.alteracoes_aflicoes_atacante[Af.RUINA] = alvo.aflicoes[Af.RUINA]

	# --- ELEMENTO TREVAS ---
	elif el == CombatEntity.Elemento.TREVAS:
		if alvo.has_aflicao(Af.RUINA):
			var pilhas_r = alvo.aflicoes[Af.RUINA]
			if alvo.hp_atual > 0 and (pilhas_r >= alvo.hp_atual or randi_range(1, alvo.hp_atual) <= pilhas_r):
				projecao.executar_morte_imediata = true
			else:
				projecao.dano_extra_puro += pilhas_r
				projecao.alteracoes_aflicoes_alvo[Af.RUINA] = -pilhas_r
		else:
			var pilhas_totais = 0
			
			# OTIMIZAÇÃO: Iteração direta sobre a constante global para evitar alocação de array no heap
			for af_tipo in AFLICOES_CONSUMIVEIS:
				if alvo.has_aflicao(af_tipo):
					var qtd = alvo.aflicoes[af_tipo]
					pilhas_totais += qtd
					projecao.alteracoes_aflicoes_alvo[af_tipo] = -qtd
			
			if pilhas_totais > 0:
				projecao.is_tecnico = true
				projecao.intensificadores_percent += 50
				var mult_ruina = 2 if (alvo.has_aflicao(Af.ATORDOADO) or alvo.has_aflicao(Af.DERRUBADO)) else 1
				projecao.alteracoes_aflicoes_alvo[Af.RUINA] = pilhas_totais * mult_ruina
				
	# --- ELEMENTO FOGO ---
	elif el == CombatEntity.Elemento.FOGO:
		if alvo.has_aflicao(Af.MOLHADO):
			projecao.multiplicador_resistencia *= 0.5
			projecao.alteracoes_aflicoes_alvo[Af.MOLHADO] = -alvo.aflicoes[Af.MOLHADO]
			
		elif alvo.has_aflicao(Af.LAMACADO):
			projecao.multiplicador_resistencia *= 0.5
			projecao.alteracoes_aflicoes_alvo[Af.LAMACADO] = -alvo.aflicoes[Af.LAMACADO]
			var dano_esperado = int(projecao.dano_base * projecao.multiplicador_resistencia)
			projecao.alteracoes_aflicoes_alvo[Af.EMPOEIRADO] = projecao.alteracoes_aflicoes_alvo.get(Af.EMPOEIRADO, 0) + dano_esperado
			
		elif alvo.has_aflicao(Af.QUEIMADURA):
			projecao.multiplicador_resistencia *= 0.5
			
		elif alvo.has_aflicao(Af.INFECCAO):
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			var pilhas_infeccao = alvo.aflicoes[Af.INFECCAO]
			projecao.alteracoes_aflicoes_alvo[Af.INFECCAO] = -pilhas_infeccao
			projecao.alteracoes_aflicoes_alvo[Af.QUEIMADURA] = projecao.alteracoes_aflicoes_alvo.get(Af.QUEIMADURA, 0) + pilhas_infeccao
			
		if alvo.has_aflicao(Af.ELETRO_ATIVA):
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			var pilhas_eletro = alvo.aflicoes[Af.ELETRO_ATIVA]
			projecao.alteracoes_aflicoes_alvo[Af.ELETRO_ATIVA] = -pilhas_eletro
			projecao.alteracoes_aflicoes_alvo[Af.QUEIMADURA] = projecao.alteracoes_aflicoes_alvo.get(Af.QUEIMADURA, 0) + pilhas_eletro
			
		elif alvo.has_aflicao(Af.ELETRO_PASSIVA):
			var pilhas_eletro = alvo.aflicoes[Af.ELETRO_PASSIVA]
			projecao.alteracoes_aflicoes_alvo[Af.ELETRO_PASSIVA] = -pilhas_eletro
			projecao.dano_extra_puro += pilhas_eletro
	
	# --- ELEMENTO RAIO ---
	elif el == CombatEntity.Elemento.RAIO:
		
		# 1. Supercondução (Verde): Raio vs Molhado ou Lamaçado[cite: 11]
		if alvo.has_aflicao(Af.MOLHADO) or alvo.has_aflicao(Af.LAMACADO):
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			
			# O GDD especifica que dobra a chance e as pilhas geradas no impacto[cite: 11].
			# Como a aplicação da aflição base virá da SkillData/Executor futuramente,
			# criamos uma flag no dicionário para avisar o Executor que a aplicação 
			# deste elemento deve ser dobrada.
			projecao["multiplicador_aplicacao_aflicao"] = 2
			
		# 2. Ignição Plasmática (Amarela): Raio vs Queimadura[cite: 11]
		if alvo.has_aflicao(Af.QUEIMADURA):
			# 30% do Dano de Raio vira novas pilhas de Queimadura[cite: 11].
			# Calculamos o dano esperado até este ponto para extrair a proporção.
			var mult_atual = 1.0 + (projecao.intensificadores_percent / 100.0)
			var dano_esperado = int(projecao.dano_base * projecao.multiplicador_resistencia * mult_atual)
			
			var pilhas_ignicao = int(dano_esperado * 0.3)
			projecao.alteracoes_aflicoes_alvo[Af.QUEIMADURA] = projecao.alteracoes_aflicoes_alvo.get(Af.QUEIMADURA, 0) + pilhas_ignicao

		# 3. Alternância Eletromagnética (Amarela): Raio vs Eletrocução[cite: 11]
		# Força a mudança de polaridade[cite: 11].
		if alvo.has_aflicao(Af.ELETRO_ATIVA):
			# De Ativa para Passiva. Removemos as cargas da Ativa e passamos para a Passiva.
			var cargas = alvo.aflicoes[Af.ELETRO_ATIVA]
			projecao.alteracoes_aflicoes_alvo[Af.ELETRO_ATIVA] = projecao.alteracoes_aflicoes_alvo.get(Af.ELETRO_ATIVA, 0) - cargas
			projecao.alteracoes_aflicoes_alvo[Af.ELETRO_PASSIVA] = projecao.alteracoes_aflicoes_alvo.get(Af.ELETRO_PASSIVA, 0) + cargas
			
		elif alvo.has_aflicao(Af.ELETRO_PASSIVA):
			# De Passiva para Ativa: engatilha consumo e dano[cite: 11].
			var cargas = alvo.aflicoes[Af.ELETRO_PASSIVA]
			var cargas_perdidas = int(cargas / 2.0) # Perde metade das cargas[cite: 11]
			var cargas_restantes = cargas - cargas_perdidas
			
			projecao.alteracoes_aflicoes_alvo[Af.ELETRO_PASSIVA] = projecao.alteracoes_aflicoes_alvo.get(Af.ELETRO_PASSIVA, 0) - cargas
			projecao.alteracoes_aflicoes_alvo[Af.ELETRO_ATIVA] = projecao.alteracoes_aflicoes_alvo.get(Af.ELETRO_ATIVA, 0) + cargas_restantes
			
			# Causa dano direto igual ao total de pilhas ativas *antes* da queima[cite: 11]
			projecao.dano_extra_puro += cargas

	# --- ELEMENTO BIOLÓGICO ---
	elif el == CombatEntity.Elemento.BIOLOGICO:
		
		# 1. Interações com Aflições Base/Ambientais (Mutuamente Exclusivas)
		if alvo.has_aflicao(Af.MOLHADO):
			# Proliferação (Verde): Ataque Técnico. Dobra as pilhas e consome Molhado.
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			projecao.alteracoes_aflicoes_alvo[Af.MOLHADO] = -alvo.aflicoes[Af.MOLHADO]
			
			# Dobra as pilhas de Infecção já existentes no alvo
			var pilhas_atuais = alvo.aflicoes[Af.INFECCAO]
			if pilhas_atuais > 0:
				projecao.alteracoes_aflicoes_alvo[Af.INFECCAO] = projecao.alteracoes_aflicoes_alvo.get(Af.INFECCAO, 0) + pilhas_atuais
				
			# Flag para o Executor dobrar também a aplicação nativa deste ataque
			projecao["multiplicador_aplicacao_aflicao"] = 2
			
		elif alvo.has_aflicao(Af.LAMACADO):
			# Supercrescimento (Verde): Ataque Técnico. Triplica as pilhas e consome Lamaçado[cite: 9].
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			projecao.alteracoes_aflicoes_alvo[Af.LAMACADO] = -alvo.aflicoes[Af.LAMACADO]
			
			# Triplica as pilhas já existentes (adiciona 2x o valor atual)
			var pilhas_atuais = alvo.aflicoes[Af.INFECCAO]
			if pilhas_atuais > 0:
				projecao.alteracoes_aflicoes_alvo[Af.INFECCAO] = projecao.alteracoes_aflicoes_alvo.get(Af.INFECCAO, 0) + (pilhas_atuais * 2)
				
			projecao["multiplicador_aplicacao_aflicao"] = 3
			
		elif alvo.has_aflicao(Af.EMPOEIRADO):
			# Incubação (Amarela): Converte Empoeirado em Infecção na proporção de 1:1[cite: 9].
			var poeira = alvo.aflicoes[Af.EMPOEIRADO]
			projecao.alteracoes_aflicoes_alvo[Af.EMPOEIRADO] = -poeira
			projecao.alteracoes_aflicoes_alvo[Af.INFECCAO] = projecao.alteracoes_aflicoes_alvo.get(Af.INFECCAO, 0) + poeira
			
		elif alvo.has_aflicao(Af.QUEIMADURA):
			# Combustão Orgânica (Vermelha): -60% no Dano Final[cite: 9].
			# Multiplicar a resistência por 0.4 retira 60% do dano.
			projecao.multiplicador_resistencia *= 0.4
			
			# Falha em aplicar Infecção[cite: 9]. 
			# Criamos uma flag para o Executor abortar a aplicação nativa deste ataque.
			projecao["anular_aplicacao_infeccao"] = true
			
			# Converte o dano residual em Queimadura[cite: 9].
			# Como a Infecção normal converte 10% do dano em pilhas, usamos a mesma métrica para a Queimadura.
			var mult_atual = 1.0 + (projecao.intensificadores_percent / 100.0)
			var dano_esperado = int(projecao.dano_base * projecao.multiplicador_resistencia * mult_atual)
			var pilhas_residuais = int(dano_esperado * 0.1)
			
			projecao.alteracoes_aflicoes_alvo[Af.QUEIMADURA] = projecao.alteracoes_aflicoes_alvo.get(Af.QUEIMADURA, 0) + pilhas_residuais

		# 2. Interações Sobrepostas (Infecção)
		if alvo.has_aflicao(Af.INFECCAO):
			# Detonação Parasitária (Verde): Força a mordida imediata (Dano Direto) sem gastar as pilhas[cite: 9].
			# A "mordida" natural da Infecção causa dano igual ao número de pilhas[cite: 9].
			projecao.dano_extra_puro += alvo.aflicoes[Af.INFECCAO]

	# --- ELEMENTO TERRA ---
	elif el == CombatEntity.Elemento.TERRA:
		
		# 1. Interações de Terreno Exclusivas (Molhado vs Queimadura)
		if alvo.has_aflicao(Af.MOLHADO):
			# Corrupção Lamaçado (Amarela): Força a transformação para Lamaçado.
			var pilhas_molhado = alvo.aflicoes[Af.MOLHADO]
			projecao.alteracoes_aflicoes_alvo[Af.MOLHADO] = -pilhas_molhado
			
			# Converte as pilhas de Molhado em Lamaçado na proporção de 1:1
			projecao.alteracoes_aflicoes_alvo[Af.LAMACADO] = projecao.alteracoes_aflicoes_alvo.get(Af.LAMACADO, 0) + pilhas_molhado
			
		elif alvo.has_aflicao(Af.QUEIMADURA):
			# Extinção (Amarela): Terra remove a Queimadura instantaneamente[cite: 8].
			projecao.alteracoes_aflicoes_alvo[Af.QUEIMADURA] = -alvo.aflicoes[Af.QUEIMADURA]
			
		# 2. Interações Sobrepostas (Podem ocorrer simultaneamente com as de terreno)
		if alvo.has_aflicao(Af.INFECCAO):
			# Nutrição (Amarela): Adiciona novas pilhas de Infecção equivalentes a 20% do Dano Final no impacto[cite: 8].
			# Calculamos o dano final esperado (com os bônus e resistências processados até aqui).
			var mult_atual = 1.0 + (projecao.intensificadores_percent / 100.0)
			var dano_esperado = int(projecao.dano_base * projecao.multiplicador_resistencia * mult_atual)
			
			var pilhas_nutricao = int(dano_esperado * 0.2)
			projecao.alteracoes_aflicoes_alvo[Af.INFECCAO] = projecao.alteracoes_aflicoes_alvo.get(Af.INFECCAO, 0) + pilhas_nutricao
			
		if alvo.has_aflicao(Af.EMPOEIRADO):
			# Abrasão (Verde): Causa dano extra puro igual às pilhas de Empoeirado (não consome as pilhas)[cite: 8].
			projecao.is_tecnico = true
			projecao.intensificadores_percent += 50
			projecao.dano_extra_puro += alvo.aflicoes[Af.EMPOEIRADO]

	# --- ELEMENTO ÁGUA ---
	elif el == CombatEntity.Elemento.AGUA:
		
		# 1. Interações de Terreno Exclusivas (Queimadura vs Empoeirado)
		if alvo.has_aflicao(Af.QUEIMADURA):
			# Extinção (Amarela): Água remove a Queimadura instantaneamente[cite: 8].
			projecao.alteracoes_aflicoes_alvo[Af.QUEIMADURA] = -alvo.aflicoes[Af.QUEIMADURA]
			
		elif alvo.has_aflicao(Af.EMPOEIRADO):
			# Corrupção Lamaçado (Amarela): Converte Empoeirado em Lamaçado[cite: 8].
			var poeira = alvo.aflicoes[Af.EMPOEIRADO]
			projecao.alteracoes_aflicoes_alvo[Af.EMPOEIRADO] = -poeira
			projecao.alteracoes_aflicoes_alvo[Af.LAMACADO] = projecao.alteracoes_aflicoes_alvo.get(Af.LAMACADO, 0) + poeira
			
		# 2. Interações Sobrepostas (Infecção e Eletrocução)
		if alvo.has_aflicao(Af.INFECCAO):
			# Nutrição (Amarela): Adiciona novas pilhas de Infecção equivalentes a 20% do Dano Final[cite: 8].
			var mult_atual = 1.0 + (projecao.intensificadores_percent / 100.0)
			var dano_esperado = int(projecao.dano_base * projecao.multiplicador_resistencia * mult_atual)
			
			var pilhas_nutricao = int(dano_esperado * 0.2)
			projecao.alteracoes_aflicoes_alvo[Af.INFECCAO] = projecao.alteracoes_aflicoes_alvo.get(Af.INFECCAO, 0) + pilhas_nutricao
			
		if alvo.has_aflicao(Af.ELETRO_ATIVA) or alvo.has_aflicao(Af.ELETRO_PASSIVA):
			# Polarização (Amarela): Muda a polaridade e obriga a ativação SEM decair as pilhas[cite: 8].
			if alvo.has_aflicao(Af.ELETRO_ATIVA):
				# Transita para Passiva. Em condições normais perderia metade, mas a Polarização previne a perda[cite: 8].
				var cargas = alvo.aflicoes[Af.ELETRO_ATIVA]
				projecao.alteracoes_aflicoes_alvo[Af.ELETRO_ATIVA] = -cargas
				projecao.alteracoes_aflicoes_alvo[Af.ELETRO_PASSIVA] = projecao.alteracoes_aflicoes_alvo.get(Af.ELETRO_PASSIVA, 0) + cargas
				
			elif alvo.has_aflicao(Af.ELETRO_PASSIVA):
				# Transita para Ativa engatilhando o dano total da bateria, novamente sem perder as cargas[cite: 8].
				var cargas = alvo.aflicoes[Af.ELETRO_PASSIVA]
				projecao.alteracoes_aflicoes_alvo[Af.ELETRO_PASSIVA] = -cargas
				projecao.alteracoes_aflicoes_alvo[Af.ELETRO_ATIVA] = projecao.alteracoes_aflicoes_alvo.get(Af.ELETRO_ATIVA, 0) + cargas
				
				# Causa o dano direto correspondente a 100% das cargas intactas[cite: 8].
				projecao.dano_extra_puro += cargas
