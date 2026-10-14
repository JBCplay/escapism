extends Node3D

# ==========================================
# CONFIGURAÇÕES (PREENCHA COM SEUS CAMINHOS)
# ==========================================

# PLACEHOLDER DE CAMINHOS DOS HEROIS - SUBSTITUA PELOS CAMINHOS REAIS DOS SEUS MODELOS
var hero_scenes = [
	"res://assets/models/robot/robot.tscn",
	"res://assets/models/shaman/shaman.glb",
	"res://assets/models/knight_standing/knightStandingColored.glb"
]

# ESTRUTURA DOS BIOMAS
var biomes = {
	"Moxon": {
		"stage": "res://Trailer/CombatScene/StageTeste.tscn",
		"floor_color": Color("4a1c1c"), # Chão avermelhado escuro
		"sky_top_color": Color("780000"), # Céu vermelho escuro no topo
		"sky_bottom_color": Color("c1121f"), # Horizonte vermelho vivo
		"fog_color": Color("c1121f"), # Neblina vermelha
		"enemies": [
			"res://assets/models/lowpoly_golem/lowpoly_golem.glb",
			"res://assets/models/observador/observador.glb",
			"res://assets/models/cubito/cubito.glb",
			"res://assets/models/cubos erraticos/cubos_erraticos.tscn"
		]
	},
	"Pholyx": {
		"stage": "res://Trailer/CombatScene/StageTeste.tscn",
		"floor_color": Color("2d1b4e"), # Chão roxo escuro
		"sky_top_color": Color("3c096c"), # Céu roxo profundo no topo
		"sky_bottom_color": Color("7b2cbf"), # Horizonte roxo vibrante
		"fog_color": Color("7b2cbf"), # Neblina roxa
		"enemies": [
			"res://assets/models/low_poly_eye/low_poly_eye.tscn",
			"res://assets/models/ghost/ghost.glb",
			"res://assets/models/slime/slime.glb"
		]
	},
	"Aelys": {
		"stage": "res://Trailer/CombatScene/StageTeste.tscn",
		"floor_color": Color("b59449"), # Chão dourado/areia
		"sky_top_color": Color("f77f00"), # Topo âmbar/amarelo queimado
		"sky_bottom_color": Color("fcbf49"), # Horizonte amarelo intenso
		"fog_color": Color("fcbf49"), # Neblina amarela
		"enemies": [
			"res://assets/models/skeleton_melee_-_animated_game_ready/skeleton_melee_-_animated_game_ready.glb",
			"res://assets/models/low_poly_rhinoceros_beetle/low_poly_rhinoceros_beetle.glb",
			"res://assets/models/mummy/mummy.tscn"
		]
	}
}

# AJUSTES INDIVIDUAIS DOS MODELOS (Altura Y e Rotação em Graus X, Y, Z)
var model_adjustments = {
	# Heróis
	"res://assets/models/robot/robot.tscn": {"y_offset": 0.2, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/shaman/shaman.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/knight_standing/knightStandingColored.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, -90, 0)},
	
	# Inimigos - Moxon
	"res://assets/models/lowpoly_golem/lowpoly_golem.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/observador/observador.glb": {"y_offset": 0.2, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/cubito/cubito.glb": {"y_offset": 0.2, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/cubos erraticos/cubos_erraticos.tscn": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	
	# Inimigos - Pholyx
	"res://assets/models/low_poly_eye/low_poly_eye.tscn": {"y_offset": 0.2, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/ghost/ghost.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/slime/slime.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	
	# Inimigos - Aelys
	"res://assets/models/skeleton_melee_-_animated_game_ready/skeleton_melee_-_animated_game_ready.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/low_poly_rhinoceros_beetle/low_poly_rhinoceros_beetle.glb": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)},
	"res://assets/models/mummy/mummy.tscn": {"y_offset": 0.0, "rot_offset": Vector3(0, 0, 0)}
}

# ==========================================
# NÓS DA CENA
# ==========================================
@onready var stage_parent = $Stage
@onready var heroes_parent = $Actors/Heroes
@onready var enemies_parent = $Actors/Enemies

var environment_node: WorldEnvironment

# --- ALINHAMENTO PARALELO ---
# Os heróis ficam na linha X = -4.0. Variam a posição no eixo Z.
var hero_positions = [Vector3(-4.0, 0, 0), Vector3(-4.0, 0, 2.5), Vector3(-4.0, 0, -2.5)]
# Os inimigos ficam na linha X = 4.0. Variam a posição no eixo Z.
var enemy_positions = [
	Vector3(4.0, 0, 0), Vector3(4.0, 0, 2.5), Vector3(4.0, 0, -2.5),
	Vector3(4.0, 0, 5.0), Vector3(4.0, 0, -5.0), Vector3(4.0, 0, 7.5)
]

func _ready():
	randomize()
	setup_world_environment()
	generate_take()

func setup_world_environment():
	environment_node = get_node_or_null("WorldEnvironment")
	if not environment_node:
		environment_node = WorldEnvironment.new()
		environment_node.name = "WorldEnvironment"
		add_child(environment_node)
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 1.5
	env.glow_bloom = 0.2
	
	env.fog_enabled = true
	env.fog_sky_affect = 1.0
	
	# Se a sua versão da Godot suportar Depth Fog (Godot 4.3+), mantém os primeiros 12 metros
	# totalmente limpos (onde ocorre a luta) e fecha 100% a neblina aos 35 metros.
	if "fog_mode" in env:
		env.set("fog_mode", 1) # 1 = Environment.FOG_MODE_DEPTH
		env.set("fog_depth_begin", 12.0)
		env.set("fog_depth_end", 35.0)
		env.set("fog_depth_curve", 1.5)
	else:
		# Fallback suave caso esteja na Godot 4.0 a 4.2 (funciona em conjunto com o chão ampliado abaixo)
		env.fog_density = 0.045
	
	environment_node.environment = env
	
func _input(event):
	if event.is_action_pressed("ui_accept"):
		generate_take()

func generate_take():
	print("--- GERANDO NOVO TAKE ---")
	clear_scene()

	var biome_keys = biomes.keys()
	var selected_biome_name = biome_keys[randi() % biome_keys.size()]
	var biome_data = biomes[selected_biome_name]
	
	var stage_scene = load(biome_data["stage"]) as PackedScene
	if stage_scene:
		var stage_instance = stage_scene.instantiate()
		stage_parent.add_child(stage_instance)
		paint_stage(stage_instance, biome_data["floor_color"])
	
	update_environment_colors(biome_data["sky_top_color"], biome_data["sky_bottom_color"], biome_data["fog_color"])

	# HERÓIS
	var num_heroes = randi_range(1, 3)
	var available_heroes = hero_scenes.duplicate()
	available_heroes.shuffle()
	var spawned_heroes = []

	for i in range(num_heroes):
		var hero_path = available_heroes.pop_back()
		var hero_scene = load(hero_path) as PackedScene
		if hero_scene:
			var hero = hero_scene.instantiate()
			heroes_parent.add_child(hero)
			hero.position = hero_positions[i]
			# Força heróis a olharem para a direita
			hero.rotation_degrees = Vector3(0, 90, 0)
			spawned_heroes.append(hero)
			setup_stats(hero, true)
			setup_animator(hero, hero_path) # <-- Passando o hero_path aqui
			fix_camera_target(hero)

	# INIMIGOS
	var num_enemies = randi_range(1, 6)
	var spawned_enemies = []
	
	for i in range(num_enemies):
		var enemy_path = biome_data["enemies"][randi() % biome_data["enemies"].size()]
		var enemy_scene = load(enemy_path) as PackedScene
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			enemies_parent.add_child(enemy)
			enemy.position = enemy_positions[i]
			# Força inimigos a olharem para a esquerda
			enemy.rotation_degrees = Vector3(0, -90, 0)
			spawned_enemies.append(enemy)
			setup_stats(enemy, false)
			setup_animator(enemy, enemy_path) # <-- Passando o enemy_path aqui
			fix_camera_target(enemy)

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
		
		var element_list = ["fogo", "raio", "trevas", "agua"]
		var attack_element = element_list[randi() % element_list.size()]
		var is_critical = randf() < 0.25
		
		var anim = attacker.get_node_or_null("ProceduralAnimator")
		if anim:
			var on_impact = func():
				$"FakeUI".animate_press()
				$"Cameras".play_hit_effect(target, attack_element, is_critical, attacker)
				
			await get_tree().create_timer(0.5).timeout
			anim.attack_dash(target.global_position, on_impact)
			$"Cameras".focus_action(attacker, target)

func setup_stats(actor, is_hero):
	var max_hp = randi_range(60, 120)
	var current_hp = int(max_hp * randf_range(0.1, 1.0))
	var max_energy = randi_range(60, 120)
	var current_energy = int(min(current_hp * randf_range(0.5, 1.1), max_energy))
	
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

func setup_animator(actor: Node3D, model_path: String = ""):
	# Pivô que o ProceduralAnimator vai animar (pulo e balanço)
	var anim_pivot = Node3D.new()
	anim_pivot.name = "AnimPivot"
	
	# Nó filho que guarda a correção de altura e rotação sem conflitar com a animação
	var offset_node = Node3D.new()
	offset_node.name = "OffsetNode"
	
	# Move todas as malhas do ator para dentro do OffsetNode (resolve modelos com mais de uma mesh)
	for child in actor.get_children():
		actor.remove_child(child)
		offset_node.add_child(child)
		
	# Aplica os ajustes configurados no dicionário model_adjustments
	if model_adjustments.has(model_path):
		var adj = model_adjustments[model_path]
		offset_node.position.y = adj.get("y_offset", 0.0)
		offset_node.rotation_degrees = adj.get("rot_offset", Vector3.ZERO)
		
	anim_pivot.add_child(offset_node)
	actor.add_child(anim_pivot)
	
	var anim = ProceduralAnimator.new()
	anim.name = "ProceduralAnimator"
	anim.root_node = actor
	anim.model_node = anim_pivot
	actor.add_child(anim)

func paint_stage(stage: Node3D, color: Color):
	for child in stage.get_children():
		if child is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			child.set_surface_override_material(0, mat)
			# Estica a plataforma em 6x nos eixos X e Z para jogar a borda para longe da câmera
			child.scale *= Vector3(6.0, 1.0, 6.0)
			break

func update_environment_colors(sky_top: Color, sky_bottom: Color, fog: Color):
	if environment_node and environment_node.environment:
		var env = environment_node.environment
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_top
			sky_mat.sky_horizon_color = fog
			# Igualamos o fundo do horizonte à cor da neblina para sumir com o vazio abaixo da plataforma
			sky_mat.ground_horizon_color = fog
			sky_mat.ground_bottom_color = fog
		env.fog_light_color = fog

func fix_camera_target(actor: Node3D):
	var target = Marker3D.new()
	target.name = "CamTarget"
	target.position = Vector3(0, 1.5, 0)
	actor.add_child(target)
