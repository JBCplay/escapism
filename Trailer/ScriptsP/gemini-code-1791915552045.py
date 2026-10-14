code = """extends Node3D

# ==========================================
# CONFIGURAÇÕES (PREENCHA COM SEUS CAMINHOS)
# ==========================================

# PLACEHOLDER DE CAMINHOS DOS HEROIS - SUBSTITUA PELOS CAMINHOS REAIS DOS SEUS MODELOS
var hero_scenes = [
\t"res://assets/models/robot/robot.glb",
\t"res://assets/models/shaman/shaman.glb",
\t"res://assets/models/knight_standing/knightStandingColored.glb"
]

# ESTRUTURA DOS BIOMAS
# Agora cada bioma define as cores que pintaremos o StageTeste proceduralmente!
var biomes = {
\t"Moxon": {
\t\t"stage": "res://Trailer/CombatScene/StageTeste.tscn",
\t\t"floor_color": Color("5a4a42"), # Marrom escuro
\t\t"sky_top_color": Color("1a1a24"), # Céu noturno
\t\t"sky_bottom_color": Color("2d283e"),
\t\t"fog_color": Color("3b3247"),
\t\t"enemies": [
\t\t\t"res://assets/models/lowpoly_golem/lowpoly_golem.glb",
\t\t\t"res://assets/models/observador/observador.glb",
\t\t\t"res://assets/models/cubito/Cubito.glb",
\t\t\t"res://assets/models/cubos erraticos/cubos_erraticos.tscn"
\t\t]
\t},
\t"Pholyx": {
\t\t"stage": "res://Trailer/CombatScene/StageTeste.tscn",
\t\t"floor_color": Color("2b4c3f"), # Verde pântano
\t\t"sky_top_color": Color("1b2a2f"), # Céu esverdeado escuro
\t\t"sky_bottom_color": Color("334a45"),
\t\t"fog_color": Color("263833"),
\t\t"enemies": [
\t\t\t"res://assets/models/low_poly_eye/low_poly_eye.glb",
\t\t\t"res://assets/models/ghost/ghost.glb",
\t\t\t"res://assets/models/slime/slime.glb"
\t\t]
\t},
\t"Aelys": {
\t\t"stage": "res://Trailer/CombatScene/StageTeste.tscn",
\t\t"floor_color": Color("c2b280"), # Areia deserto
\t\t"sky_top_color": Color("3a86ff"), # Céu azul claro
\t\t"sky_bottom_color": Color("ffbe0b"), # Horizonte amarelado
\t\t"fog_color": Color("e9c46a"),
\t\t"enemies": [
\t\t\t"res://assets/models/skeleton_melee_-_animated_game_ready/skeleton_melee_-_animated_game_ready.glb",
\t\t\t"res://assets/models/low_poly_rhinoceros_beetle/low_poly_rhinoceros_beetle.glb",
\t\t\t"res://assets/models/mummy/mummy.glb"
\t\t]
\t}
}

# ==========================================
# NÓS DA CENA
# ==========================================
# Assumindo a estrutura: TrailerCombat -> Stage / Actors(Heroes, Enemies)
@onready var stage_parent = $Stage
@onready var heroes_parent = $Actors/Heroes
@onready var enemies_parent = $Actors/Enemies

# Adicionamos um nó WorldEnvironment (se não existir, o script cria!)
var environment_node: WorldEnvironment

# Posições fixas para formação (Ajuste conforme sua câmera)
var hero_positions = [Vector3(-2, 0, 0), Vector3(-4, 0, 2), Vector3(-4, 0, -2)]
# Até 6 inimigos em 2 fileiras
var enemy_positions = [Vector3(2, 0, 0), Vector3(4, 0, 2), Vector3(4, 0, -2), Vector3(3, 0, 4), Vector3(5, 0, 0), Vector3(3, 0, -4)]

func _ready():
\trandomize()
\tsetup_world_environment()
\t# Gera a cena logo no frame 1 para o Movie Maker já gravar
\tgenerate_take()

func setup_world_environment():
\t# Verifica se já existe um WorldEnvironment na cena
\tenvironment_node = get_node_or_null("WorldEnvironment")
\tif not environment_node:
\t\tenvironment_node = WorldEnvironment.new()
\t\tenvironment_node.name = "WorldEnvironment"
\t\tadd_child(environment_node)
\t
\tvar env = Environment.new()
\t
\t# Configurações base para visual Low-Poly bacana
\tenv.background_mode = Environment.BG_SKY
\tvar sky = Sky.new()
\tvar sky_mat = ProceduralSkyMaterial.new()
\tsky.sky_material = sky_mat
\tenv.sky = sky
\t
\t# SSAO e Glow para dar aquele "tchan"
\tenv.ssao_enabled = true
\tenv.ssao_radius = 1.5
\tenv.ssao_intensity = 2.0
\tenv.glow_enabled = true
\tenv.glow_intensity = 1.5
\tenv.glow_bloom = 0.2
\t
\t# Ativa neblina volumétrica simples
\tenv.fog_enabled = true
\tenv.fog_density = 0.02
\t
\tenvironment_node.environment = env

func _input(event):
\t# Aperte a barra de ESPAÇO (ou 'ui_accept') para rerolar o take em tempo real
\tif event.is_action_pressed("ui_accept"):
\t\tgenerate_take()

func generate_take():
\tprint("--- GERANDO NOVO TAKE ---")
\tclear_scene()

\t# 1. BIOMA
\tvar biome_keys = biomes.keys()
\tvar selected_biome_name = biome_keys[randi() % biome_keys.size()]
\tvar biome_data = biomes[selected_biome_name]
\t
\t# CARREGA O STAGE BASEADO NO BIOMA ESCOLHIDO (PLACEHOLDER)
\tvar stage_scene = load(biome_data["stage"]) as PackedScene
\tif stage_scene:
\t\tvar stage_instance = stage_scene.instantiate()
\t\tstage_parent.add_child(stage_instance)
\t\t# PINTA O CHÃO DO STAGETESTE
\t\tpaint_stage(stage_instance, biome_data["floor_color"])
\t
\t# ATUALIZA O CÉU E A NÉVOA
\tupdate_environment_colors(biome_data["sky_top_color"], biome_data["sky_bottom_color"], biome_data["fog_color"])

\t# 2. HERÓIS (1 a 3, sem repetir)
\tvar num_heroes = randi_range(1, 3)
\tvar available_heroes = hero_scenes.duplicate()
\tavailable_heroes.shuffle()
\tvar spawned_heroes = []

\tfor i in range(num_heroes):
\t\tvar hero_path = available_heroes.pop_back()
\t\t# CARREGA O MODELO DO HEROI (PLACEHOLDER)
\t\tvar hero_scene = load(hero_path) as PackedScene
\t\tif hero_scene:
\t\t\tvar hero = hero_scene.instantiate()
\t\t\theroes_parent.add_child(hero)
\t\t\thero.position = hero_positions[i]
\t\t\thero.rotation_degrees.y = 90 # Olhando para a direita
\t\t\tspawned_heroes.append(hero)
\t\t\tsetup_stats(hero, true)
\t\t\tsetup_animator(hero)
\t\t\tfix_camera_target(hero) # Garante que as câmeras possam focar nele

\t# 3. INIMIGOS (1 a 6, pode repetir)
\tvar num_enemies = randi_range(1, 6)
\tvar spawned_enemies = []
\t
\tfor i in range(num_enemies):
\t\tvar enemy_path = biome_data["enemies"][randi() % biome_data["enemies"].size()]
\t\t# CARREGA O MODELO DO INIMIGO (PLACEHOLDER)
\t\tvar enemy_scene = load(enemy_path) as PackedScene
\t\tif enemy_scene:
\t\t\tvar enemy = enemy_scene.instantiate()
\t\t\tenemies_parent.add_child(enemy)
\t\t\tenemy.position = enemy_positions[i]
\t\t\tenemy.rotation_degrees.y = -90 # Olhando para a esquerda
\t\t\tspawned_enemies.append(enemy)
\t\t\tsetup_stats(enemy, false)
\t\t\tsetup_animator(enemy)
\t\t\tfix_camera_target(enemy) # Garante que as câmeras possam focar nele

\t# 4. SELECIONAR ATACANTE E ALVO
\tvar is_hero_attacking = randi() % 2 == 0
\tvar attacker = null
\tvar target = null

\tif is_hero_attacking and spawned_heroes.size() > 0 and spawned_enemies.size() > 0:
\t\tattacker = spawned_heroes.pick_random()
\t\ttarget = spawned_enemies.pick_random()
\telif spawned_enemies.size() > 0 and spawned_heroes.size() > 0:
\t\tattacker = spawned_enemies.pick_random()
\t\ttarget = spawned_heroes.pick_random()
\t
\tif attacker and target:
\t\tprint("Atacante Selecionado: ", attacker.name, " | Alvo: ", target.name)
\t\t
\t\t$"FakeUI".setup_ui(is_hero_attacking)
\t\t
\t\t# Sorteia elemento
\t\tvar element_list = ["fogo", "raio", "trevas", "agua"]
\t\tvar attack_element = element_list[randi() % element_list.size()]
\t\t
\t\t# Sorteia chance de crítico (ex: 25% de chance)
\t\tvar is_critical = randf() < 0.25
\t\t
\t\tprint("Ataque -> Elemento: ", attack_element, " | Crítico: ", is_critical)
\t\t
\t\t# Procura o componente ProceduralAnimator dentro do atacante
\t\tvar anim = attacker.get_node_or_null("ProceduralAnimator")
\t\t
\t\tif anim:
\t\t\t# Removemos a chamada dupla redundante que estava aqui!
\t\t\tvar on_impact = func():
\t\t\t\t$"FakeUI".animate_press()
\t\t\t\t$"Cameras".play_hit_effect(target, attack_element, is_critical)
\t\t\t\t
\t\t\t# Dá um tempinho antes de atacar para as partículas do bioma (névoa) assentarem
\t\t\tawait get_tree().create_timer(0.5).timeout
\t\t\tanim.attack_dash(target.global_position, on_impact)
\t\t\t
\t\t\t# Corta para a câmera de ação no atacante!
\t\t\t$"Cameras".focus_action(attacker)

func setup_stats(actor, is_hero):
\t# Max HP e Energia entre 60 e 120
\tvar max_hp = randi_range(60, 120)
\tvar max_energy = randi_range(60, 120)
\t
\t# Vida atual como uma razão qualquer da vida máxima (ex: 10% a 100%)
\tvar current_hp = int(max_hp * randf_range(0.1, 1.0))
\t
\t# Energia atual entre 50% e 110% do HP atual, mas sem passar do max_energy
\tvar energy_ratio = randf_range(0.5, 1.1)
\tvar current_energy = int(min(current_hp * energy_ratio, max_energy))
\t
\t# Salva como Metadata para a UI ler depois
\tactor.set_meta("max_hp", max_hp)
\tactor.set_meta("current_hp", current_hp)
\tactor.set_meta("max_energy", max_energy)
\tactor.set_meta("current_energy", current_energy)

func clear_scene():
\tfor child in stage_parent.get_children():
\t\tchild.queue_free()
\tfor child in heroes_parent.get_children():
\t\tchild.queue_free()
\tfor child in enemies_parent.get_children():
\t\tchild.queue_free()

func setup_animator(actor: Node3D):
\t# Cria o nó do componente dinamicamente
\tvar anim = ProceduralAnimator.new()
\tanim.name = "ProceduralAnimator"
\tactor.add_child(anim)
\t
\t# O nó raiz (que desliza até o inimigo) é o próprio modelo
\tanim.root_node = actor
\t
\t# O nó visual (que pula e balança) é a malha dentro do .glb
\tif actor.get_child_count() > 0:
\t\tanim.model_node = actor.get_child(0)
\telse:
\t\tanim.model_node = actor

# --- FUNÇÕES NOVAS DE PINTURA E CÂMERA ---

func paint_stage(stage: Node3D, color: Color):
\t# Procura por um MeshInstance3D no StageTeste para aplicar a cor
\tfor child in stage.get_children():
\t\tif child is MeshInstance3D:
\t\t\tvar mat = StandardMaterial3D.new()
\t\t\tmat.albedo_color = color
\t\t\tchild.set_surface_override_material(0, mat)
\t\t\tbreak # Pinta apenas o chão principal

func update_environment_colors(sky_top: Color, sky_bottom: Color, fog: Color):
\tif environment_node and environment_node.environment:
\t\tvar env = environment_node.environment
\t\tif env.sky and env.sky.sky_material is ProceduralSkyMaterial:
\t\t\tvar sky_mat = env.sky.sky_material as ProceduralSkyMaterial
\t\t\tsky_mat.sky_top_color = sky_top
\t\t\tsky_mat.sky_horizon_color = sky_bottom
\t\t\tsky_mat.ground_horizon_color = sky_bottom
\t\t\tsky_mat.ground_bottom_color = sky_bottom.darkened(0.5)
\t\t
\t\tenv.fog_light_color = fog

func fix_camera_target(actor: Node3D):
\t# Adiciona um nó vazio (Target) na altura do peito do personagem
\t# para as câmeras focarem nele em vez de focarem nos pés (0,0,0)
\tvar target = Marker3D.new()
\ttarget.name = "CamTarget"
\ttarget.position = Vector3(0, 1.5, 0) # Altura padrão
\tactor.add_child(target)
"""
with open("TrailerDirector_3.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("TrailerDirector_3.gd created successfully with tag: [file-tag: TrailerDirector_3-xxxxxxxxxx]")