extends Node3D

# --- CARREGAMENTO DAS MALHAS (.tres) ---
var malha_raso = preload("res://raso.tres")
var malha_parede = preload("res://parede.tres")
var malha_rampa = preload("res://rampa.tres")

# --- CONFIGURAÇÕES DO MOTOR ---
const HASH_SIZE = 256
const RAIO_NEVOA = 4
const LRU_CAPACITY = 64 
const HEX_RAIO = 2.5 
const ALTURA_DEGRAU = 0.5

const LIVRE = -1
const RASO = 0
const PAREDE = 1
const RAMPA_CIMA = 2
const MAX_AMOSTRAS_VALIDAS = 8 # X candidatos. Se achar 5 viáveis, para de procurar!

# --- O TRADUTOR LÓGICO (O DNA DOS TILES) ---
var definicao_tiles = {
	0: [LIVRE, LIVRE, LIVRE, LIVRE, LIVRE, LIVRE],                   # ID 0: CORINGA (Anomalia)
	1: [RASO, RASO, RASO, RASO, RASO, RASO],                         # ID 1: Clareira Plana
	2: [RASO, RASO, PAREDE, RASO, RASO, PAREDE],                     # ID 2: Encruzilhada
	3: [RASO, PAREDE, PAREDE, PAREDE, PAREDE, PAREDE],               # ID 3: Beco sem Saída
	5: [RASO, PAREDE, PAREDE, RASO, PAREDE, PAREDE],                 # ID 5: Corredor Reto
	9: [RASO, RASO, PAREDE, PAREDE, PAREDE, PAREDE],                 # ID 9: Curva Fechada
	
	# === NOVAS PEÇAS DE ELEVAÇÃO ===
	10: [RAMPA_CIMA, RASO, RASO, RASO, RASO, RASO],                  # ID 10: Rampa + 5 Rasos
	11: [RAMPA_CIMA, RAMPA_CIMA, RASO, RASO, RASO, RASO],            # ID 11: 2 Rampas + 4 Rasos
	12: [PAREDE, RAMPA_CIMA, PAREDE, RASO, PAREDE, RASO],            # ID 12: Interseção com Rampa
	13: [RAMPA_CIMA, PAREDE, PAREDE, RASO, PAREDE, PAREDE],          # ID 13: Corredor de Subida
	14: [RAMPA_CIMA, PAREDE, PAREDE, RAMPA_CIMA, RASO, RASO],        # ID 14: Curva em Subida Dupla
	
	# === NOVAS PEÇAS COMPLEXAS E PREENCHIMENTOS ===
	15: [PAREDE, RASO, PAREDE, RASO, PAREDE, RASO],                  # ID 15: Interseção em Y (3 caminhos)
	16: [PAREDE, RAMPA_CIMA, PAREDE, RASO, RASO, RASO],              # ID 16: Interseção em T com Rampa
	17: [PAREDE, RASO, PAREDE, RAMPA_CIMA, RAMPA_CIMA, RAMPA_CIMA],  # ID 17: Rampa Tripla (Subida Épica)
	18: [PAREDE, PAREDE, PAREDE, PAREDE, PAREDE, PAREDE],            # ID 18: Pilar Maciço (O Salvador do Look-Ahead)
	19: [RAMPA_CIMA, RAMPA_CIMA, RAMPA_CIMA, RASO, RASO, RASO],      # ID 19: Meia subida / Meio raso
	20: [RASO, RASO, RASO, PAREDE, PAREDE, PAREDE],                  # ID 20: Borda de penhasco (Meio raso/Meia parede)
	21: [PAREDE, PAREDE, RASO, RASO, RASO, RASO],                    # ID 21: Canto interno amplo
	22: [PAREDE, RASO, RASO, RASO, RASO, RASO],                      # ID 22: Parede isolada
	
	# === PEÇAS DE TENSÃO TOPOLÓGICA (Para o Amortecedor Elástico) ===
	23: [RAMPA_CIMA, RASO, RAMPA_CIMA, RASO, RASO, RASO],            # ID 23: Rampa, Raso, Rampa (A peça que você viu faltar)
	24: [RAMPA_CIMA, RASO, RASO, RAMPA_CIMA, RASO, RASO],            # ID 24: Rampas Opostas (Subida em dois sentidos)
	25: [RAMPA_CIMA, RAMPA_CIMA, PAREDE, RASO, RASO, PAREDE],        # ID 25: Curva Dupla de Subida com contenção
	26: [RAMPA_CIMA, PAREDE, RAMPA_CIMA, PAREDE, RAMPA_CIMA, PAREDE],# ID 26: Escadaria em Espiral (Subida tripla alternada)
	27: [RAMPA_CIMA, RASO, PAREDE, RAMPA_CIMA, RASO, PAREDE],        # ID 27: Subida dividida por paredes
	28: [RAMPA_CIMA, RASO, RASO, RASO, RASO, PAREDE],                # ID 28: Subida suave beirando muro
	29: [RAMPA_CIMA, RAMPA_CIMA, RASO, RASO, PAREDE, PAREDE]         # ID 29: Rampa dupla de canto
}

@export var hex_template: PackedScene

# --- ESTRUTURAS DE DADOS ---
var cache_estatica: Array = []
var lru_pool_nodes: Array[Node3D] = []

# Estado Global
var jogador_q: int = 0
var jogador_r: int = 0
var profundidade_expedicao: int = 0
var tick_global: int = 0

# --- VETORES DIRECIONAIS (Anti-Horários, sincronizados com Godot) ---
var dir_q = [1, 1, 0, -1, -1, 0]
var dir_r = [0, -1, -1, 0, 1, 1]

# --- INICIALIZAÇÃO ---
func _ready():
	for i in range(HASH_SIZE):
		cache_estatica.append({
			"ativa": false,
			"identidade": 0,
			"rotacao": 0,
			"nivel_z": 0,
			"pool_index": -1 
		})
		
	for i in range(LRU_CAPACITY):
		var nova_sala = hex_template.instantiate()
		nova_sala.visible = false
		nova_sala.set_meta("tick_uso", 0) 
		add_child(nova_sala)
		lru_pool_nodes.append(nova_sala)
		
	print("[INIT] Motor Inicializado. Gerando visão inicial...")
	gerar_visao_radial(jogador_q, jogador_r, RAIO_NEVOA)

# --- MATEMÁTICA E CULLING ---
func calcular_index(q: int, r: int) -> int:
	return ((r & 15) << 4) | (q & 15)

func limpar_anel_de_descarte(jq: int, jr: int, raio: int):
	var anel_q = jq + (dir_q[4] * raio)
	var anel_r = jr + (dir_r[4] * raio)
	for i in range(6):
		for j in range(raio):
			var index = calcular_index(anel_q, anel_r)
			if cache_estatica[index]["ativa"]:
				cache_estatica[index]["ativa"] = false
				var pool_idx = cache_estatica[index]["pool_index"]
				if pool_idx != -1:
					lru_pool_nodes[pool_idx].visible = false
			anel_q += dir_q[i]
			anel_r += dir_r[i]

func obter_no_lru() -> int:
	var index_mais_velho = 0
	var menor_tick = tick_global + 1
	for i in range(LRU_CAPACITY):
		var no = lru_pool_nodes[i]
		if not no.visible: return i 
		var tick_no = no.get_meta("tick_uso")
		if tick_no < menor_tick:
			menor_tick = tick_no
			index_mais_velho = i
	return index_mais_velho

func distancia_hex(q1: int, r1: int, q2: int, r2: int) -> int:
	var s1 = -q1 - r1
	var s2 = -q2 - r2
	return max(abs(q1 - q2), max(abs(r1 - r2), abs(s1 - s2)))

func reset_total_memoria():
	print("[SISTEMA] Salto longo detectado. Resetando memória visual...")
	for i in range(HASH_SIZE):
		cache_estatica[i]["ativa"] = false
		cache_estatica[i]["pool_index"] = -1
	for no in lru_pool_nodes:
		no.visible = false

# --- INTELIGÊNCIA TOPOLÓGICA VERTICAL ---
# Calcula a variação e define o Nível Z do tile atual junto com as exigências.
func calcular_nivel_ideal_e_requisitos(q: int, r: int) -> Dictionary:
	var req = [LIVRE, LIVRE, LIVRE, LIVRE, LIVRE, LIVRE]
	var alturas_exigidas = []
	var vizinhos_data = {}
	
	# 1. Coleta e Filtro de Alturas
	for i in range(6):
		var v_q = q + dir_q[i]
		var v_r = r + dir_r[i]
		var idx_v = calcular_index(v_q, v_r)
		
		if cache_estatica[idx_v]["ativa"]:
			var v_z = cache_estatica[idx_v]["nivel_z"]
			var dir_oposta = (i + 3) % 6
			var v_id = cache_estatica[idx_v]["identidade"]
			var v_rot = cache_estatica[idx_v]["rotacao"]
			var bordas_originais = definicao_tiles[v_id]
			var viz_borda = bordas_originais[(dir_oposta - v_rot + 6) % 6]
			
			vizinhos_data[i] = {"borda": viz_borda, "z": v_z}
			if viz_borda != PAREDE:
				var altura_efetiva = v_z
				if viz_borda == RAMPA_CIMA:
					altura_efetiva = v_z + 1
				alturas_exigidas.append(altura_efetiva)
				vizinhos_data[i]["eff_h"] = altura_efetiva
		else:
			vizinhos_data[i] = null
			
	# === O AMORTECEDOR ELÁSTICO (Correção Ativa de Tensão) ===
	var todas_alturas_locais = []
	for i in range(6):
		if vizinhos_data[i] != null:
			todas_alturas_locais.append(vizinhos_data[i]["z"])
			
	var direcao_tensao = 0 # 0 = Normal, 1 = Puxa pra Cima, -1 = Puxa pra Baixo
	
	if todas_alturas_locais.size() > 0:
		var z_max_local = todas_alturas_locais.max()
		var z_min_local = todas_alturas_locais.min()
		
		# Só agimos se a diferença for absurda (>= 2)
		if (z_max_local - z_min_local) >= 2:
			var soma = 0.0
			for z in todas_alturas_locais: soma += z
			var media_z = soma / todas_alturas_locais.size()
			
			var min_h_temp = alturas_exigidas.min() if alturas_exigidas.size() > 0 else z_min_local
			
			if min_h_temp < media_z - 0.5:
				direcao_tensao = 1  # Estamos num buraco em relação às paredes! SUBIR!
			elif min_h_temp > media_z + 0.5:
				direcao_tensao = -1 # Estamos num pico em relação ao resto! DESCER!

	# 2. A Variação de Altura
	var meu_z = 0
	var anomalia = false
	
	if alturas_exigidas.size() > 0:
		var min_h = alturas_exigidas.min()
		var max_h = alturas_exigidas.max()
		if (max_h - min_h) > 1: anomalia = true 
		meu_z = min_h
		
		if alturas_exigidas.size() == 1:
			var borda_vizinho_unico = RASO
			for i in range(6):
				if vizinhos_data[i] != null and vizinhos_data[i]["borda"] != PAREDE:
					borda_vizinho_unico = vizinhos_data[i]["borda"]
					break
					
			# === AÇÃO 1 DA TENSÃO: Tentar Descer ===
			if borda_vizinho_unico == RASO:
				if direcao_tensao == -1:
					# Tensão repuxa pra baixo! DESCIDA FORÇADA para aliviar o pico.
					meu_z = min_h - 1
				elif direcao_tensao == 0 and randf() < 0.15:
					# Terreno normal, descida orgânica aleatória.
					meu_z = min_h - 1
					
	else:
		# Fallback de zonas mortas
		var idx_centro = calcular_index(jogador_q, jogador_r)
		if cache_estatica[idx_centro]["ativa"]:
			meu_z = cache_estatica[idx_centro]["nivel_z"]
		else:
			meu_z = 0

	# 3. O Tradutor Topológico Consciente de Altura
	for i in range(6):
		if vizinhos_data[i] != null:
			var viz_borda = vizinhos_data[i]["borda"]
			
			if viz_borda == PAREDE:
				req[i] = PAREDE
			else:
				var eff_h = vizinhos_data[i]["eff_h"]
				if meu_z == eff_h:
					req[i] = RASO
				elif meu_z == eff_h - 1:
					req[i] = RAMPA_CIMA
				else:
					req[i] = PAREDE # Hard Override (Abismo ou buraco mortal)
					
	return {"requisitos": req, "nivel_z": meu_z, "anomalia": anomalia, "direcao_tensao": direcao_tensao}

# --- INTELIGÊNCIA PREDITIVA (LOOK-AHEAD) ---
# --- LOOK-AHEAD OTIMIZADO ---
# Pré-calcula os vizinhos reais de C uma única vez para poupar processamento
func pre_calcular_contexto_c(c_q: int, c_r: int) -> Dictionary:
	var v_data = {}
	for i in range(6):
		var vv_q = c_q + dir_q[i]
		var vv_r = c_r + dir_r[i]
		var idx_vv = calcular_index(vv_q, vv_r)
		
		if cache_estatica[idx_vv]["ativa"]:
			var vv_z = cache_estatica[idx_vv]["nivel_z"]
			var vv_id = cache_estatica[idx_vv]["identidade"]
			var vv_rot = cache_estatica[idx_vv]["rotacao"]
			var b_orig = definicao_tiles[vv_id]
			var dir_oposta = (i + 3) % 6
			var vv_borda = b_orig[(dir_oposta - vv_rot + 6) % 6]
			
			var eff = vv_z
			if vv_borda == RAMPA_CIMA: eff = vv_z + 1
			v_data[i] = {"borda": vv_borda, "z": vv_z, "eff_h": eff}
		else:
			v_data[i] = null
	return v_data

# Avaliação hiper-rápida usando o contexto em cache
func avaliar_opcoes_rapido(v_data: Dictionary, dir_A: int, borda_A: int, z_A: int) -> int:
	var alturas_ex = []
	var req_C = [LIVRE, LIVRE, LIVRE, LIVRE, LIVRE, LIVRE]
	
	var eff_A = z_A
	if borda_A == RAMPA_CIMA: eff_A = z_A + 1
	
	if borda_A != PAREDE: alturas_ex.append(eff_A)
		
	for i in range(6):
		if i != dir_A and v_data[i] != null and v_data[i]["borda"] != PAREDE:
			alturas_ex.append(v_data[i]["eff_h"])
			
	var c_z = z_A
	if alturas_ex.size() > 0:
		var min_h = alturas_ex.min()
		var max_h = alturas_ex.max()
		if (max_h - min_h) > 1: return 0 
		c_z = min_h
		
	for i in range(6):
		if i == dir_A:
			if borda_A == PAREDE: req_C[i] = PAREDE
			elif c_z == eff_A: req_C[i] = RASO
			elif c_z == eff_A - 1: req_C[i] = RAMPA_CIMA
			else: req_C[i] = PAREDE
		elif v_data[i] != null:
			var viz_borda = v_data[i]["borda"]
			if viz_borda == PAREDE: req_C[i] = PAREDE
			else:
				var eff_h = v_data[i]["eff_h"]
				if c_z == eff_h: req_C[i] = RASO
				elif c_z == eff_h - 1: req_C[i] = RAMPA_CIMA
				else: req_C[i] = PAREDE
				
	var opcoes = 0
	for id in definicao_tiles.keys():
		if id == 0: continue
		var bordas = definicao_tiles[id]
		for rot in range(6):
			var encaixa = true
			for dir in range(6):
				if req_C[dir] != LIVRE and bordas[(dir - rot + 6) % 6] != req_C[dir]:
					encaixa = false
					break
			if encaixa:
				opcoes += 1
				# MICRO-OTIMIZAÇÃO: Não precisamos procurar mais. Se tem 4 formas de salvar C, já é ótimo.
				if opcoes >= 4: return 4 
	return opcoes

func escolher_tile_compativel(requisitos: Array, q: int, r: int, meu_z: int, direcao_tensao: int = 0) -> Dictionary:
		# --- 0. MICRO-OTIMIZAÇÃO E DETEÇÃO PREMATURA DE PARADOXO ---
	var cache_futuro = {}
	var ids_vizinhos = []
	
	for dir in range(6):
		var v_q = q + dir_q[dir]
		var v_r = r + dir_r[dir]
		var idx_v = calcular_index(v_q, v_r)
		
		# Coleta vizinhos para a penalidade
		if cache_estatica[idx_v]["ativa"]:
			ids_vizinhos.append(cache_estatica[idx_v]["identidade"])
			
		# Pré-calcula os espaços livres
		if requisitos[dir] == LIVRE:
			var v_data = pre_calcular_contexto_c(v_q, v_r)
			
			var alturas_ex_C = []
			for i in range(6):
				if v_data[i] != null and v_data[i]["borda"] != PAREDE:
					alturas_ex_C.append(v_data[i]["eff_h"])
					
			if alturas_ex_C.size() > 0:
				var min_h = alturas_ex_C.min()
				var max_h = alturas_ex_C.max()
				if (max_h - min_h) > 1:
					# A CURA: O futuro C já está quebrado pelas outras paredes/rampas.
					# Marcamos C como "condenado". O Tile A vai ignorar C e gerar normalmente!
					cache_futuro[dir] = "condenado"
					continue
					
			cache_futuro[dir] = v_data

	var candidatos_iniciais = []
	
	# 1. Busca egoísta (Quem encaixa perfeitamente nas bordas do Tile A?)
	for id in definicao_tiles.keys():
		if id == 0: continue 
		var bordas = definicao_tiles[id]
		for rot in range(6):
			var encaixou = true
			for dir in range(6):
				if requisitos[dir] != LIVRE:
					if bordas[(dir - rot + 6) % 6] != requisitos[dir]:
						encaixou = false
						break
			if encaixou:
				candidatos_iniciais.append({"id": id, "rotacao": rot, "bordas_reais": bordas})
				
	if candidatos_iniciais.is_empty():
		return {"id": 0, "rotacao": 0}
		
	candidatos_iniciais.shuffle()

	# 2. Busca Altruísta Estocástica (Limitada a X amostras)
	var candidatos_com_peso = []
	var total_peso = 0.0
	
	for cand in candidatos_iniciais:
		var score_do_candidato = 0.0
		var anomalia_detectada = false
		
		for dir in range(6):
			if requisitos[dir] == LIVRE:
				# A CURA PARTE 2: Ignora C no Look-Ahead se ele já estiver condenado!
				if typeof(cache_futuro[dir]) == TYPE_STRING and cache_futuro[dir] == "condenado":
					continue
					
				var minha_borda_para_C = cand["bordas_reais"][(dir - cand["rotacao"] + 6) % 6]
				var dir_de_C_para_A = (dir + 3) % 6
				
				var opcoes_C = avaliar_opcoes_rapido(cache_futuro[dir], dir_de_C_para_A, minha_borda_para_C, meu_z)
				
				if opcoes_C == 0:
					anomalia_detectada = true 
					break
				else:
					score_do_candidato += opcoes_C
					
		# --- INÍCIO DO BLOCO AJUSTADO ---
		if not anomalia_detectada:
			# Penalidade Anti-Repetição
			if cand["id"] in ids_vizinhos:
				score_do_candidato *= 0.3 
				
			# === AÇÃO 2 DA TENSÃO: Tentar Subir ou Segurar a Descida ===
			if direcao_tensao != 0:
				var qtd_rampas_novas = 0
				for d in range(6):
					if requisitos[d] == LIVRE: 
						var minha_borda_para_C = cand["bordas_reais"][(d - cand["rotacao"] + 6) % 6]
						if minha_borda_para_C == RAMPA_CIMA:
							qtd_rampas_novas += 1
				
				if direcao_tensao == 1:
					# Precisamos SUBIR! Se a peça aponta rampa pro futuro, multiplicamos o peso por 3x!
					if qtd_rampas_novas > 0:
						score_do_candidato *= (3.0 * qtd_rampas_novas) 
					else:
						# Se for plana, punimos pra evitar estagnação no buraco.
						score_do_candidato *= 0.2 
						
				elif direcao_tensao == -1:
					# Nós já tentamos descer no 'meu_z'. Punimos brutalmente qualquer rampa que tente subir de volta!
					if qtd_rampas_novas > 0:
						score_do_candidato *= 0.01 
			
			if score_do_candidato > 0:
				candidatos_com_peso.append({
					"id": cand["id"],
					"rotacao": cand["rotacao"],
					"peso": score_do_candidato
				})
				total_peso += score_do_candidato
				
				# O FREIO DA BUSCA ESTOCÁSTICA CONTINUA AQUI
				if candidatos_com_peso.size() >= MAX_AMOSTRAS_VALIDAS:
					break
		# --- FIM DO BLOCO AJUSTADO ---
				
	# 3. Decisão Final Inteligente (Roleta Viciada)
	if candidatos_com_peso.size() > 0:
		var sorteio = randf_range(0.0, total_peso)
		var peso_acumulado = 0.0
		
		for cand in candidatos_com_peso:
			peso_acumulado += cand["peso"]
			if sorteio <= peso_acumulado:
				return {"id": cand["id"], "rotacao": cand["rotacao"]}
				
		var ultimo = candidatos_com_peso.back()
		return {"id": ultimo["id"], "rotacao": ultimo["rotacao"]}
	else:
		# Se todos na amostragem levam a anomalias, pega o primeiro que a roleta sorteou na Busca Egoísta
		var sorteado_b = candidatos_iniciais.front()
		return {"id": sorteado_b["id"], "rotacao": sorteado_b["rotacao"]}

# --- GERAÇÃO VISUAL E LOOK-AHEAD ---
func instanciar_sala_3d(q: int, r: int, index_hash: int, nova_identidade: int, rotacao: int, nivel_z: int):
	var pool_idx = obter_no_lru()
	var sala_node = lru_pool_nodes[pool_idx]
	
	cache_estatica[index_hash]["pool_index"] = pool_idx
	sala_node.set_meta("tick_uso", tick_global)
	
	var espacamento = sqrt(3.0) * HEX_RAIO
	var pos_x = espacamento * (q + float(r) / 2.0)
	var pos_z = 1.5 * HEX_RAIO * r
	
	# === NOVA DIMENSÃO VERTICAL APLICADA AQUI ===
	sala_node.position = Vector3(pos_x, nivel_z * ALTURA_DEGRAU, pos_z)
	
	var bordas = definicao_tiles[nova_identidade]
	for i in range(6):
		var borda_node = sala_node.get_node("Pivo_" + str(i) + "/Borda_Mesh")
		var tipo_borda = bordas[(i - rotacao + 6) % 6]
		
		# === FÁBRICA DE BORDAS (Com ajuste de Posição Dinâmico) ===
		if tipo_borda == RASO:
			borda_node.mesh = null
			borda_node.position = Vector3.ZERO 
		elif tipo_borda == PAREDE:
			borda_node.mesh = malha_parede
			borda_node.rotation_degrees.y = 90
			# Mantém a parede fina no limite do tile
			borda_node.position = Vector3(1.965, 1.0, 0)
		elif tipo_borda == RAMPA_CIMA:
			borda_node.mesh = malha_rampa
			borda_node.rotation_degrees.y = 0  
			# Magia Matemática: Se a rampa tem X=2.0, colocamos o centro dela em 1.165.
			# Assim, a ponta final dela bate perfeitamente em 2.165 (limite do hexágono) sem invadir!
			borda_node.position = Vector3(1.165, 0.25, 0) 
		else:
			borda_node.mesh = null
			
		# Limpa colisões antigas no nó do pivô antes de aplicar nova malha
		for child in borda_node.get_children():
			child.queue_free()

		if tipo_borda == PAREDE or tipo_borda == RAMPA_CIMA:
			# Cria automaticamente a colisão física baseada na nova posição
			borda_node.create_trimesh_collision()
	
	# === SISTEMA DE CORES DINÂMICO PARA DEBUG ===
	var material = StandardMaterial3D.new()
	
	if nova_identidade == 0:
		material.albedo_color = Color(0.0, 1.0, 1.0) # Ciano: TILE CORINGA
	elif nova_identidade == 1:
		material.albedo_color = Color(0.4, 0.4, 0.4) # Cinza: Clareira (6 Rasos)
	else:
		# Conta dinamicamente as características da peça
		var qtd_paredes = bordas.count(PAREDE)
		var qtd_rampas = bordas.count(RAMPA_CIMA)
		
		if qtd_rampas == 0:
			# --- TILES PLANOS (Sem Rampas) ---
			if qtd_paredes >= 5:
				material.albedo_color = Color(0.8, 0.2, 0.2) # Vermelho (Becos e Pilares Maciços)
			elif qtd_paredes == 3 or qtd_paredes == 4:
				material.albedo_color = Color(0.8, 0.2, 0.8) # Roxo (Curvas e Corredores fechados)
			elif qtd_paredes == 1 or qtd_paredes == 2:
				material.albedo_color = Color(0.2, 0.2, 0.8) # Azul (Encruzilhadas e corredores abertos)
		else:
			# --- TILES COM ELEVAÇÃO (Com Rampas) ---
			if qtd_paredes == 0:
				material.albedo_color = Color(1.0, 0.8, 0.0) # Amarelo (Rampas Livres/Abertas)
			else:
				# --- SUGESTÃO: Rampas com Paredes ---
				material.albedo_color = Color(1.0, 0.5, 0.0) # Laranja (Subidas restritas/ladeadas por muros)
				
	sala_node.get_node("Centro_Piso").material_override = material
	sala_node.visible = true
		
	sala_node.get_node("Centro_Piso").material_override = material
	sala_node.visible = true

func gerar_visao_radial(jq: int, jr: int, raio: int):
	var idx_centro = calcular_index(jq, jr)
	if not cache_estatica[idx_centro]["ativa"]:
		profundidade_expedicao += 1
		cache_estatica[idx_centro]["ativa"] = true
		cache_estatica[idx_centro]["identidade"] = 1
		cache_estatica[idx_centro]["rotacao"] = 0
		cache_estatica[idx_centro]["nivel_z"] = 0
		instanciar_sala_3d(jq, jr, idx_centro, 1, 0, 0)
		
	for rad in range(1, raio + 1):
		var anel_q = jq + (dir_q[4] * rad)
		var anel_r = jr + (dir_r[4] * rad)
		
		for i in range(6):
			for j in range(rad):
				var index = calcular_index(anel_q, anel_r)
				
				if not cache_estatica[index]["ativa"]:
					profundidade_expedicao += 1
					
					# === NOVA GERAÇÃO CONSCIENTE DE ALTURA ===
					var analise = calcular_nivel_ideal_e_requisitos(anel_q, anel_r)
					var escolha = {"id": 0, "rotacao": 0}
					
					if not analise["anomalia"]:
						escolha = escolher_tile_compativel(analise["requisitos"], anel_q, anel_r, analise["nivel_z"], analise.get("direcao_tensao", 0))
					else:
						# Como você reverteu a solução do pilar maciço, voltamos ao aviso original:
						print("[AVISO] Paradoxo de Altura. Forçando Curinga!")
					
					cache_estatica[index]["ativa"] = true
					cache_estatica[index]["identidade"] = escolha["id"]
					cache_estatica[index]["rotacao"] = escolha["rotacao"]
					cache_estatica[index]["nivel_z"] = analise["nivel_z"]
					
					instanciar_sala_3d(anel_q, anel_r, index, escolha["id"], escolha["rotacao"], analise["nivel_z"])
					
				else:
					var pool_idx = cache_estatica[index]["pool_index"]
					if pool_idx != -1:
						lru_pool_nodes[pool_idx].set_meta("tick_uso", tick_global)
						
				anel_q += dir_q[i]
				anel_r += dir_r[i]

# --- CONVERSOR 3D PARA HEXAGONAL ---
func world_to_hex(pos_x: float, pos_z: float) -> Vector2i:
	var px = pos_x / HEX_RAIO
	var pz = pos_z / HEX_RAIO
	var q_float = (sqrt(3.0) / 3.0 * px - 1.0 / 3.0 * pz)
	var r_float = 2.0 / 3.0 * pz
	var s_float = -q_float - r_float
	
	var q_round = round(q_float)
	var r_round = round(r_float)
	var s_round = round(s_float)
	
	var q_diff = abs(q_round - q_float)
	var r_diff = abs(r_round - r_float)
	var s_diff = abs(s_round - s_float)
	
	if q_diff > r_diff and q_diff > s_diff:
		q_round = -r_round - s_round
	elif r_diff > s_diff:
		r_round = -q_round - s_round
		
	return Vector2i(int(q_round), int(r_round))

# --- O SENSOR DE MOVIMENTO ---
func _process(_delta):
	if not has_node("Boxxie"): return
	var pos_boxxie = $Boxxie.global_position
	var hex_atual = world_to_hex(pos_boxxie.x, pos_boxxie.z)
	
	if hex_atual.x != jogador_q or hex_atual.y != jogador_r:
		var salto = distancia_hex(jogador_q, jogador_r, hex_atual.x, hex_atual.y)
		jogador_q = hex_atual.x
		jogador_r = hex_atual.y
		tick_global += 1
		
		if salto == 1:
			limpar_anel_de_descarte(jogador_q, jogador_r, RAIO_NEVOA + 1)
		else:
			reset_total_memoria()
			
		gerar_visao_radial(jogador_q, jogador_r, RAIO_NEVOA)
