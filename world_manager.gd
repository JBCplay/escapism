extends Node3D

# --- CONFIGURAÇÕES DO MOTOR ---
const HASH_SIZE = 256
const RAIO_NEVOA = 4
const LRU_CAPACITY = 64 # Suporta as 61 células visíveis do raio 4 com folga

@export var hex_template: PackedScene

# --- ESTRUTURAS DE DADOS ---
# Camada 1: O Toro Espacial (Array de 256 posições)
var cache_estatica: Array = []

# Camada 2: O Object Pool (As 64 instâncias 3D)
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
	# 1. Inicializa a Hash Estática (Matriz Achatada)
	for i in range(HASH_SIZE):
		cache_estatica.append({
			"ativa": false,
			"identidade": 0,
			"pool_index": -1 # Qual nó 3D do pool está representando esta célula
		})
		
	# 2. Inicializa o Object Pool (Instancia 64 nós invisíveis na memória)
	for i in range(LRU_CAPACITY):
		var nova_sala = hex_template.instantiate()
		nova_sala.visible = false
		
		# Injetamos um meta-dado no nó para rastrear quando ele foi usado por último
		nova_sala.set_meta("tick_uso", 0) 
		
		add_child(nova_sala)
		lru_pool_nodes.append(nova_sala)
		
	print("[INIT] Motor Inicializado. Gerando visão inicial...")
	gerar_visao_radial(jogador_q, jogador_r, RAIO_NEVOA)

# --- MATEMÁTICA E CULLING ---
func calcular_index(q: int, r: int) -> int:
	# A mágica do Toro 16x16 convertida para GDScript
	return ((r & 15) << 4) | (q & 15)

func limpar_anel_de_descarte(jq: int, jr: int, raio: int):
	var anel_q = jq + (dir_q[4] * raio)
	var anel_r = jr + (dir_r[4] * raio)
	
	for i in range(6):
		for j in range(raio):
			var index = calcular_index(anel_q, anel_r)
			
			if cache_estatica[index]["ativa"]:
				cache_estatica[index]["ativa"] = false
				
				# Desliga a visibilidade da sala 3D correspondente
				var pool_idx = cache_estatica[index]["pool_index"]
				if pool_idx != -1:
					lru_pool_nodes[pool_idx].visible = false
					
			anel_q += dir_q[i]
			anel_r += dir_r[i]

# --- GERENCIADOR DO OBJECT POOL (LRU) ---
func obter_no_lru() -> int:
	# Procura um nó invisível (livre) ou o mais velho para sobrescrever
	var index_mais_velho = 0
	var menor_tick = tick_global + 1
	
	for i in range(LRU_CAPACITY):
		var no = lru_pool_nodes[i]
		if not no.visible:
			return i # Achou um livre, retorna na hora
			
		var tick_no = no.get_meta("tick_uso")
		if tick_no < menor_tick:
			menor_tick = tick_no
			index_mais_velho = i
			
	# Se todos estão visíveis (o que não deve ocorrer se dimensionado certo), ejeta o mais velho
	return index_mais_velho

# --- GERAÇÃO PROCEDURAL (LOOK-AHEAD) ---
func instanciar_sala_3d(q: int, r: int, index_hash: int, nova_identidade: int):
	var pool_idx = obter_no_lru()
	var sala_node = lru_pool_nodes[pool_idx]
	
	# Atualiza a cache
	cache_estatica[index_hash]["pool_index"] = pool_idx
	sala_node.set_meta("tick_uso", tick_global)
	
	# --- MATEMÁTICA ESPACIAL 3D ---
	var espacamento = sqrt(3.0)
	var pos_x = espacamento * (q + float(r) / 2.0)
	var pos_z = 1.5 * r
	
	# Posiciona e liga a sala no Godot
	sala_node.position = Vector3(pos_x, 0, pos_z)
	
	# --- SIMULADOR DE TILES VISUAIS ---
	# Cria um novo material 3D dinamicamente para pintar a sala
	var material = StandardMaterial3D.new()
	
	if nova_identidade == 42:
		# ID 42 = Sala Perigosa (Vermelha e mais alta)
		material.albedo_color = Color(0.8, 0.1, 0.1) # Vermelho escuro
		sala_node.scale = Vector3(1, 2, 1)
		sala_node.rotation_degrees.y = 60
	elif nova_identidade == 99:
		# ID 99 = Sala de Tesouro/Chefe (Dourada)
		material.albedo_color = Color(0.9, 0.8, 0.2) # Dourado
		sala_node.scale = Vector3(1, 1, 1)
		sala_node.rotation_degrees.y = 0
	else:
		# ID 1 = Corredor Padrão (Cinza)
		material.albedo_color = Color(0.4, 0.4, 0.4) # Cinza
		sala_node.scale = Vector3(1, 1, 1)
		sala_node.rotation_degrees.y = 0
	
	sala_node.get_node("HexTile").material_override = material
		
	sala_node.visible = true

func gerar_visao_radial(jq: int, jr: int, raio: int):
	# Centro (Só vai rodar na inicialização do jogo em 0,0)
	var idx_centro = calcular_index(jq, jr)
	if not cache_estatica[idx_centro]["ativa"]:
		profundidade_expedicao += 1
		cache_estatica[idx_centro]["ativa"] = true
		cache_estatica[idx_centro]["identidade"] = 1 # O marco zero sempre será seguro (Cinza)
		instanciar_sala_3d(jq, jr, idx_centro, cache_estatica[idx_centro]["identidade"])
		
	# Anéis concêntricos (É AQUI que o mapa real nasce)
	for rad in range(1, raio + 1):
		var anel_q = jq + (dir_q[4] * rad)
		var anel_r = jr + (dir_r[4] * rad)
		
		for i in range(6):
			for j in range(rad):
				var index = calcular_index(anel_q, anel_r)
				
				if not cache_estatica[index]["ativa"]:
					profundidade_expedicao += 1
					cache_estatica[index]["ativa"] = true
					
					# --- NOVA LÓGICA DE SELEÇÃO UNIFICADA ---
					var nova_id = 1 # Padrão: Cinza
					
					if profundidade_expedicao % 15 == 0:
						nova_id = 99 # A cada 15 salas geradas, nasce uma Amarela (Chefe/Tesouro)
					elif profundidade_expedicao % 5 == 0:
						nova_id = 42 # A cada 5 salas geradas, nasce uma Vermelha (Perigo)
						
					cache_estatica[index]["identidade"] = nova_id
					instanciar_sala_3d(anel_q, anel_r, index, cache_estatica[index]["identidade"])
					
				else:
					# Cache Hit! Apenas atualiza o LRU tick para proteger de evicção
					var pool_idx = cache_estatica[index]["pool_index"]
					if pool_idx != -1:
						lru_pool_nodes[pool_idx].set_meta("tick_uso", tick_global)
						
				anel_q += dir_q[i]
				anel_r += dir_r[i]

# --- LOOP DE MOVIMENTO E CONTROLE ---
func mover_jogador(direcao: int):
	tick_global += 1
	jogador_q += dir_q[direcao]
	jogador_r += dir_r[direcao]
	
	limpar_anel_de_descarte(jogador_q, jogador_r, RAIO_NEVOA + 1)
	gerar_visao_radial(jogador_q, jogador_r, RAIO_NEVOA)
	
	# Move a câmera do WorldManager para seguir o jogador (Básico)
	var espacamento = sqrt(3.0)
	var pos_x = espacamento * (jogador_q + float(jogador_r) / 2.0)
	var pos_z = 1.5 * jogador_r
	
	# Animação suave provisória da câmera
	var tween = create_tween()
	tween.tween_property($Camera3D, "position", Vector3(pos_x, 10, pos_z), 0.2)

# Controle rápido pelo teclado para você testar (sem precisar configurar Input Maps)
func _unhandled_key_input(event):
	if event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_D: mover_jogador(0) # Leste
			KEY_X: mover_jogador(1) # Sudeste
			KEY_Z: mover_jogador(2) # Sudoeste
			KEY_A: mover_jogador(3) # Oeste
			KEY_W: mover_jogador(4) # Noroeste
			KEY_E: mover_jogador(5) # Nordeste
