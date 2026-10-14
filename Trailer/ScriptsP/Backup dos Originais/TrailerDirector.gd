extends Node3D

# ==========================================
# CONFIGURAÇÕES (PREENCHA COM SEUS CAMINHOS)
# ==========================================

# PLACEHOLDER DE CAMINHOS DOS HEROIS - SUBSTITUA PELOS CAMINHOS REAIS DOS SEUS MODELOS
var hero_scenes = [
	"res://assets/models/robot/robot.glb",
	"res://assets/models/shaman/shaman.glb",
	"res://assets/models/knight_standing/knightStandingColored.glb"
]

# ESTRUTURA DOS BIOMAS
# PLACEHOLDER DOS STAGES E INIMIGOS DE CADA BIOMA
var biomes = {
	"Moxon": {
		"stage": "res://Trailer/CombatScene/StageTeste.tscn",
		"enemies": [
			"res://assets/models/lowpoly_golem/lowpoly_golem.glb",
			"res://assets/models/observador/observador.glb",
			"res://assets/models/cubito/Cubito.glb",
			"res://assets/models/cubos erraticos/cubos_erraticos.tscn"
		]
	},
	"Pholyx": {
		"stage": "res://Trailer/CombatScene/StageTeste.tscn",
		"enemies": [
			"res://assets/models/low_poly_eye/low_poly_eye.glb",
			"res://assets/models/ghost/ghost.glb",
			"res://assets/models/slime/slime.glb"
		]
	},
	"Aelys": {
		"stage": "res://Trailer/CombatScene/StageTeste.tscn",
		"enemies": [
			"res://assets/models/skeleton_melee_-_animated_game_ready/skeleton_melee_-_animated_game_ready.glb",
			"res://assets/models/low_poly_rhinoceros_beetle/low_poly_rhinoceros_beetle.glb",
			"res://assets/models/mummy/mummy.glb"
		]
	}
}

# ==========================================
# NÓS DA CENA
# ==========================================
# Assumindo a estrutura: TrailerCombat -> Stage / Actors(Heroes, Enemies)
@onready var stage_parent = $Stage
@onready var heroes_parent = $Actors/Heroes
@onready var enemies_parent = $Actors/Enemies

# Posições fixas para formação (Ajuste conforme sua câmera)
var hero_positions = [Vector3(-2, 0, 0), Vector3(-4, 0, 2), Vector3(-4, 0, -2)]
# Até 6 inimigos em 2 fileiras
var enemy_positions = [Vector3(2, 0, 0), Vector3(4, 0, 2), Vector3(4, 0, -2), Vector3(3, 0, 4), Vector3(5, 0, 0), Vector3(3, 0, -4)]

func _ready():
	randomize()
	# Gera a cena logo no frame 1 para o Movie Maker já gravar
	generate_take()

func _input(event):
	# Aperte a barra de ESPAÇO (ou 'ui_accept') para rerolar o take em tempo real
	if event.is_action_pressed("ui_accept"):
		generate_take()

func generate_take():
	print("--- GERANDO NOVO TAKE ---")
	clear_scene()

	# 1. BIOMA
	var biome_keys = biomes.keys()
	var selected_biome_name = biome_keys[randi() % biome_keys.size()]
	var biome_data = biomes[selected_biome_name]
	
	# CARREGA O STAGE BASEADO NO BIOMA ESCOLHIDO (PLACEHOLDER)
	var stage_scene = load(biome_data["stage"]) as PackedScene
	if stage_scene:
		var stage_instance = stage_scene.instantiate()
		stage_parent.add_child(stage_instance)

	# 2. HERÓIS (1 a 3, sem repetir)
	var num_heroes = randi_range(1, 3)
	var available_heroes = hero_scenes.duplicate()
	available_heroes.shuffle()
	var spawned_heroes = []

	for i in range(num_heroes):
		var hero_path = available_heroes.pop_back()
		# CARREGA O MODELO DO HEROI (PLACEHOLDER)
		var hero_scene = load(hero_path) as PackedScene
		if hero_scene:
			var hero = hero_scene.instantiate()
			heroes_parent.add_child(hero)
			hero.position = hero_positions[i]
			hero.rotation_degrees.y = 90 # Olhando para a direita
			spawned_heroes.append(hero)
			setup_stats(hero, true)
			setup_animator(hero)

	# 3. INIMIGOS (1 a 6, pode repetir)
	var num_enemies = randi_range(1, 6)
	var spawned_enemies = []
	
	for i in range(num_enemies):
		var enemy_path = biome_data["enemies"][randi() % biome_data["enemies"].size()]
		# CARREGA O MODELO DO INIMIGO (PLACEHOLDER)
		var enemy_scene = load(enemy_path) as PackedScene
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			enemies_parent.add_child(enemy)
			enemy.position = enemy_positions[i]
			enemy.rotation_degrees.y = -90 # Olhando para a esquerda
			spawned_enemies.append(enemy)
			setup_stats(enemy, false)
			setup_animator(enemy)

	# 4. SELECIONAR ATACANTE E ALVO
	var is_hero_attacking = randi() % 2 == 0
	var attacker = null
	var target = null

	if is_hero_attacking and spawned_heroes.size() > 0 and spawned_enemies.size() > 0:
		attacker = spawned_heroes.pick_random()
		target = spawned_enemies.pick_random()
	elif spawned_enemies.size() > 0 and spawned_heroes.size() > 0:
		attacker = spawned_enemies.pick_random()
		target = spawned_heroes.pick_random()
	
	if attacker and target:
		print("Atacante Selecionado: ", attacker.name, " | Alvo: ", target.name)
		
		$"FakeUI".setup_ui(is_hero_attacking)
		
		# Sorteia elemento
		var element_list = ["fogo", "raio", "trevas", "agua"]
		var attack_element = element_list[randi() % element_list.size()]
		
		# Sorteia chance de crítico (ex: 25% de chance)
		var is_critical = randf() < 0.25
		
		print("Ataque -> Elemento: ", attack_element, " | Crítico: ", is_critical)
		
		print("Ataque -> Elemento: ", attack_element, " | Crítico: ", is_critical)
		
		# Procura o componente ProceduralAnimator dentro do atacante
		var anim = attacker.get_node_or_null("ProceduralAnimator")
		
		if anim:
			# Criamos uma função anônima que engatilha tudo do momento do impacto
			var on_impact = func():
				$"FakeUI".animate_press()
				$"Cameras".play_hit_effect(target, attack_element, is_critical)
				
			# Manda o atacante dar o dash, passando a posição do alvo e a função de impacto
			anim.attack_dash(target.global_position, on_impact)
		
		$"FakeUI".animate_press()
		$"Cameras".play_hit_effect(target, attack_element, is_critical)
		
		# AQUI VOCÊ SINALIZARIA PARA A CÂMERA E PARA O ANIMATION PLAYER INICIAREM O TAKE
		# ex: start_combat_action(attacker, target)

func setup_stats(actor, is_hero):
	# Max HP e Energia entre 60 e 120
	var max_hp = randi_range(60, 120)
	var max_energy = randi_range(60, 120)
	
	# Vida atual como uma razão qualquer da vida máxima (ex: 10% a 100%)
	var current_hp = int(max_hp * randf_range(0.1, 1.0))
	
	# Energia atual entre 50% e 110% do HP atual, mas sem passar do max_energy
	var energy_ratio = randf_range(0.5, 1.1)
	var current_energy = int(min(current_hp * energy_ratio, max_energy))
	
	# Salva como Metadata para a UI ler depois
	actor.set_meta("max_hp", max_hp)
	actor.set_meta("current_hp", current_hp)
	actor.set_meta("max_energy", max_energy)
	actor.set_meta("current_energy", current_energy)

func clear_scene():
	for child in stage_parent.get_children():
		child.queue_free()
	for child in heroes_parent.get_children():
		child.queue_free()
	for child in enemies_parent.get_children():
		child.queue_free()

func setup_animator(actor: Node3D):
	# Cria o nó do componente dinamicamente
	var anim = ProceduralAnimator.new()
	anim.name = "ProceduralAnimator"
	actor.add_child(anim)
	
	# O nó raiz (que desliza até o inimigo) é o próprio modelo
	anim.root_node = actor
	
	# O nó visual (que pula e balança) é a malha dentro do .glb
	if actor.get_child_count() > 0:
		anim.model_node = actor.get_child(0)
	else:
		anim.model_node = actor
