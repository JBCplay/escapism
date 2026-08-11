extends Node3D

# --- CARREGAMENTO DAS MALHAS (.tres) ---
var malha_raso = preload("res://raso.tres")
var malha_parede = preload("res://parede.tres")
var malha_rampa = preload("res://rampa.tres")

# --- CONFIGURAÇÕES DO MOTOR ---
const HASH_SIZE = 256
const RAIO_NEVOA = 4
const LRU_CAPACITY = 64 
const HEX_RAIO = 2.5 # Novo tamanho do tile

const LIVRE = -1
const RASO = 0
const PAREDE = 1
const RAMPA_CIMA = 2
const RAMPA_BAIXO = 3

# --- O TRADUTOR LÓGICO (O DNA DOS TILES) ---
var definicao_tiles = {
	0: [LIVRE, LIVRE, LIVRE, LIVRE, LIVRE, LIVRE],       # ID 0: CORINGA (Anomalia Topológica)
	1: [RASO, RASO, RASO, RASO, RASO, RASO],             # ID 1: Clareira (Tudo aberto)
	2: [RASO, RASO, PAREDE, RASO, RASO, PAREDE],         # ID 2: Encruzilhada (4 Caminhos)
	3: [RASO, PAREDE, PAREDE, PAREDE, PAREDE, PAREDE],   # ID 3: Beco sem Saída (1 Caminho)
	5: [RASO, PAREDE, PAREDE, RASO, PAREDE, PAREDE],     # ID 5: Corredor Reto
	9: [RASO, RASO, PAREDE, PAREDE, PAREDE, PAREDE]      # ID 9: Curva Fechada
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

# --- VETORES DIRECIONAIS (Anti-Horários, sincronizados com o Eixo Y da Godot) ---
# 0: Leste, 1: Nordeste, 2: Noroeste, 3: Oeste, 4: Sudoeste, 5: Sudeste
var dir_q = [1, 1, 0, -1, -1, 0]
var dir_r = [0, -1, -1, 0, 1, 1]

# --- INICIALIZAÇÃO ---
func _ready():
	for i in range(HASH_SIZE):
		cache_estatica.append({
			"ativa": false,
			"identidade": 0,
			"rotacao": 0,
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
	print("[SISTEMA] Salto longo detectado (Teleporte/Respawn). Resetando memória visual...")
	for i in range(HASH_SIZE):
		cache_estatica[i]["ativa"] = false
		cache_estatica[i]["pool_index"] = -1
	for no in lru_pool_nodes:
		no.visible = false

# --- INTELIGÊNCIA TOPOLÓGICA ---
func obter_requisitos_vizinhos(q: int, r: int) -> Array:
	var req = [LIVRE, LIVRE, LIVRE, LIVRE, LIVRE, LIVRE]
	for i in range(6):
		var v_q = q + dir_q[i]
		var v_r = r + dir_r[i]
		var idx_v = calcular_index(v_q, v_r)
		
		if cache_estatica[idx_v]["ativa"]:
			var dir_oposta = (i + 3) % 6
			var v_id = cache_estatica[idx_v]["identidade"]
			var v_rot = cache_estatica[idx_v]["rotacao"]
			
			var bordas_originais = definicao_tiles[v_id]
			# Deslocamento circular para descobrir o que o vizinho está apontando para nós
			var borda_que_aponta_pra_mim = bordas_originais[(dir_oposta - v_rot + 6) % 6]
			req[i] = borda_que_aponta_pra_mim
	return req

func escolher_tile_compativel(requisitos: Array) -> Dictionary:
	var candidatos = []
	for id in definicao_tiles.keys():
		# O Coringa não participa do sorteio natural, ele é estritamente a última esperança!
		if id == 0: 
			continue
			
		var bordas = definicao_tiles[id]
		for rot in range(6):
			var encaixou = true
			for dir in range(6):
				if requisitos[dir] != LIVRE:
					var minha_borda_visual = bordas[(dir - rot + 6) % 6]
					if minha_borda_visual != requisitos[dir]:
						encaixou = false
						break
			if encaixou:
				candidatos.append({"id": id, "rotacao": rot})
				
	if candidatos.size() > 0:
		return candidatos.pick_random()
	else:
		print("[SISTEMA] Falha topológica crítica. Injetando Tile Curinga!")
		return {"id": 0, "rotacao": 0} # O Curinga salva o dia!

# --- GERAÇÃO VISUAL E LOOK-AHEAD ---
func instanciar_sala_3d(q: int, r: int, index_hash: int, nova_identidade: int, rotacao: int):
	var pool_idx = obter_no_lru()
	var sala_node = lru_pool_nodes[pool_idx]
	
	cache_estatica[index_hash]["pool_index"] = pool_idx
	sala_node.set_meta("tick_uso", tick_global)
	
	var espacamento = sqrt(3.0) * HEX_RAIO
	var pos_x = espacamento * (q + float(r) / 2.0)
	var pos_z = 1.5 * HEX_RAIO * r
	
	sala_node.position = Vector3(pos_x, 0, pos_z)
	
	# === A MÁGICA DA FÁBRICA DE BORDAS ===
	var bordas = definicao_tiles[nova_identidade]
	
	for i in range(6):
		var borda_node = sala_node.get_node("Pivo_" + str(i) + "/Borda_Mesh")
		# Descobre qual lado lógico caiu neste pivô após girarmos a sala
		var tipo_borda = bordas[(i - rotacao + 6) % 6]
		
		# === FÁBRICA DE BORDAS (Sem Raso para evitar Z-Fighting) ===
		if tipo_borda == RASO:
			borda_node.mesh = null # Não desenha ponte, usa a passagem livre entre os pisos
		elif tipo_borda == PAREDE:
			borda_node.mesh = malha_parede
		elif tipo_borda == RAMPA_CIMA or tipo_borda == RAMPA_BAIXO:
			borda_node.mesh = malha_rampa
		else:
			borda_node.mesh = null
	
	# Pinta o chão central só pra gente saber qual ID é qual
	var material = StandardMaterial3D.new()
	if nova_identidade == 0:
		material.albedo_color = Color(0.0, 1.0, 1.0) # Ciano Brilhante: TILE CURINGA!
	elif nova_identidade == 5:
		material.albedo_color = Color(0.2, 0.2, 0.8) # Azul: Corredor Reto
	elif nova_identidade == 9:
		material.albedo_color = Color(0.8, 0.2, 0.8) # Roxo: Curva Fechada
	elif nova_identidade == 2:
		material.albedo_color = Color(0.2, 0.8, 0.2) # Verde: Encruzilhada
	elif nova_identidade == 3:
		material.albedo_color = Color(0.8, 0.2, 0.2) # Vermelho: Beco sem Saída
	else:
		material.albedo_color = Color(0.4, 0.4, 0.4) # Cinza: Clareira
		
	sala_node.get_node("Centro_Piso").material_override = material
	sala_node.visible = true

func gerar_visao_radial(jq: int, jr: int, raio: int):
	var idx_centro = calcular_index(jq, jr)
	if not cache_estatica[idx_centro]["ativa"]:
		profundidade_expedicao += 1
		cache_estatica[idx_centro]["ativa"] = true
		cache_estatica[idx_centro]["identidade"] = 1
		cache_estatica[idx_centro]["rotacao"] = 0
		instanciar_sala_3d(jq, jr, idx_centro, 1, 0)
		
	for rad in range(1, raio + 1):
		var anel_q = jq + (dir_q[4] * rad)
		var anel_r = jr + (dir_r[4] * rad)
		
		for i in range(6):
			for j in range(rad):
				var index = calcular_index(anel_q, anel_r)
				
				if not cache_estatica[index]["ativa"]:
					profundidade_expedicao += 1
					
					# GERAÇÃO GULOSA
					var requisitos = obter_requisitos_vizinhos(anel_q, anel_r)
					var escolha = escolher_tile_compativel(requisitos)
					
					cache_estatica[index]["ativa"] = true
					cache_estatica[index]["identidade"] = escolha["id"]
					cache_estatica[index]["rotacao"] = escolha["rotacao"]
					
					instanciar_sala_3d(anel_q, anel_r, index, escolha["id"], escolha["rotacao"])
					
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
# --- O SENSOR DE MOVIMENTO ---
func _process(_delta):
	if not has_node("Boxxie"):
		return
		
	var pos_boxxie = $Boxxie.global_position
	var hex_atual = world_to_hex(pos_boxxie.x, pos_boxxie.z)
	
	if hex_atual.x != jogador_q or hex_atual.y != jogador_r:
		# Mede a distância entre o hexágono antigo e o novo
		var salto = distancia_hex(jogador_q, jogador_r, hex_atual.x, hex_atual.y)
		
		jogador_q = hex_atual.x
		jogador_r = hex_atual.y
		tick_global += 1
		
		# A mágica do roteamento de performance:
		if salto == 1:
			# Jogabilidade normal: Otimização suprema usando o seu Anel
			limpar_anel_de_descarte(jogador_q, jogador_r, RAIO_NEVOA + 1)
		else:
			# Edge Case (Teleporte): Limpa tudo da RAM instantaneamente
			reset_total_memoria()
			
		gerar_visao_radial(jogador_q, jogador_r, RAIO_NEVOA)
