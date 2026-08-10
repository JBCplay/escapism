extends Node3D

# --- CONFIGURAÇÕES DO MOTOR ---
const HASH_SIZE = 256
const RAIO_NEVOA = 4
const LRU_CAPACITY = 64 

@export var hex_template: PackedScene

# --- ESTRUTURAS DE DADOS ---
var cache_estatica: Array = []
var lru_pool_nodes: Array[Node3D] = []

# Estado Global
var jogador_q: int = 0
var jogador_r: int = 0
var profundidade_expedicao: int = 0
var tick_global: int = 0

# Vetores Axiais (0: Leste, 1: Sudeste, 2: Sudoeste, 3: Oeste, 4: Noroeste, 5: Nordeste)
var dir_q = [1, 0, -1, -1, 0, 1]
var dir_r = [0, 1, 1, 0, -1, -1]

# --- INICIALIZAÇÃO ---
func _ready():
	for i in range(HASH_SIZE):
		cache_estatica.append({
			"ativa": false,
			"identidade": 0,
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

# --- GERENCIADOR DO OBJECT POOL (LRU) ---
func obter_no_lru() -> int:
	var index_mais_velho = 0
	var menor_tick = tick_global + 1
	
	for i in range(LRU_CAPACITY):
		var no = lru_pool_nodes[i]
		if not no.visible:
			return i 
			
		var tick_no = no.get_meta("tick_uso")
		if tick_no < menor_tick:
			menor_tick = tick_no
			index_mais_velho = i
			
	return index_mais_velho

# --- GERAÇÃO PROCEDURAL (LOOK-AHEAD) ---
func instanciar_sala_3d(q: int, r: int, index_hash: int, nova_identidade: int):
	var pool_idx = obter_no_lru()
	var sala_node = lru_pool_nodes[pool_idx]
	
	cache_estatica[index_hash]["pool_index"] = pool_idx
	sala_node.set_meta("tick_uso", tick_global)
	
	var espacamento = sqrt(3.0)
	var pos_x = espacamento * (q + float(r) / 2.0)
	var pos_z = 1.5 * r
	
	sala_node.position = Vector3(pos_x, 0, pos_z)
	
	var material = StandardMaterial3D.new()
	
	if nova_identidade == 42:
		material.albedo_color = Color(0.8, 0.1, 0.1) 
		sala_node.scale = Vector3(1, 2, 1)
		sala_node.rotation_degrees.y = 60
	elif nova_identidade == 99:
		material.albedo_color = Color(0.9, 0.8, 0.2) 
		sala_node.scale = Vector3(1, 1, 1)
		sala_node.rotation_degrees.y = 0
	else:
		material.albedo_color = Color(0.4, 0.4, 0.4) 
		sala_node.scale = Vector3(1, 1, 1)
		sala_node.rotation_degrees.y = 0
	
	sala_node.get_node("HexTile").material_override = material
	sala_node.visible = true

func gerar_visao_radial(jq: int, jr: int, raio: int):
	var idx_centro = calcular_index(jq, jr)
	if not cache_estatica[idx_centro]["ativa"]:
		profundidade_expedicao += 1
		cache_estatica[idx_centro]["ativa"] = true
		cache_estatica[idx_centro]["identidade"] = 1
		instanciar_sala_3d(jq, jr, idx_centro, cache_estatica[idx_centro]["identidade"])
		
	for rad in range(1, raio + 1):
		var anel_q = jq + (dir_q[4] * rad)
		var anel_r = jr + (dir_r[4] * rad)
		
		for i in range(6):
			for j in range(rad):
				var index = calcular_index(anel_q, anel_r)
				
				if not cache_estatica[index]["ativa"]:
					profundidade_expedicao += 1
					cache_estatica[index]["ativa"] = true
					
					var nova_id = 1 
					
					if profundidade_expedicao % 15 == 0:
						nova_id = 99 
					elif profundidade_expedicao % 5 == 0:
						nova_id = 42 
						
					cache_estatica[index]["identidade"] = nova_id
					instanciar_sala_3d(anel_q, anel_r, index, cache_estatica[index]["identidade"])
					
				else:
					var pool_idx = cache_estatica[index]["pool_index"]
					if pool_idx != -1:
						lru_pool_nodes[pool_idx].set_meta("tick_uso", tick_global)
						
				anel_q += dir_q[i]
				anel_r += dir_r[i]

# --- CONVERSOR 3D PARA HEXAGONAL ---
func world_to_hex(pos_x: float, pos_z: float) -> Vector2i:
	var q_float = (sqrt(3.0) / 3.0 * pos_x - 1.0 / 3.0 * pos_z)
	var r_float = 2.0 / 3.0 * pos_z
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
	# Garante que o Boxxie existe na cena antes de rastreá-lo
	if not has_node("Boxxie"):
		return
		
	# 1. Pega a posição física atual do Boxxie no mapa 3D
	var pos_boxxie = $Boxxie.global_position
	
	# 2. Converte a posição 3D para a coordenada do hexágono onde ele está pisando
	var hex_atual = world_to_hex(pos_boxxie.x, pos_boxxie.z)
	
	# 3. O Boxxie pisou em um hexágono diferente!
	if hex_atual.x != jogador_q or hex_atual.y != jogador_r:
		
		# Atualiza a posição lógica do jogador no motor
		jogador_q = hex_atual.x
		jogador_r = hex_atual.y
		tick_global += 1
		
		# Apaga o passado que ficou para trás da névoa e gera o novo horizonte!
		limpar_anel_de_descarte(jogador_q, jogador_r, RAIO_NEVOA + 1)
		gerar_visao_radial(jogador_q, jogador_r, RAIO_NEVOA)
