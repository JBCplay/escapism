code = """extends Node3D

# ==========================================
# CONFIGURAÇÕES (PREENCHA COM SEUS CAMINHOS)
# ==========================================

# PLACEHOLDER DE CAMINHOS DOS HEROIS - SUBSTITUA PELOS CAMINHOS REAIS DOS SEUS MODELOS
var hero_scenes = [
\t"res://caminho/para/seus/modelos/Heroi1.tscn",
\t"res://caminho/para/seus/modelos/Heroi2.tscn",
\t"res://caminho/para/seus/modelos/Heroi3.tscn",
\t"res://caminho/para/seus/modelos/Heroi4.tscn"
]

# ESTRUTURA DOS BIOMAS
# PLACEHOLDER DOS STAGES E INIMIGOS DE CADA BIOMA
var biomes = {
\t"floresta": {
\t\t"stage": "res://caminho/para/stages/FlorestaStage.tscn",
\t\t"enemies": [
\t\t\t"res://caminho/para/seus/modelos/InimigoGoblin.tscn",
\t\t\t"res://caminho/para/seus/modelos/InimigoLobo.tscn"
\t\t]
\t},
\t"caverna": {
\t\t"stage": "res://caminho/para/stages/CavernaStage.tscn",
\t\t"enemies": [
\t\t\t"res://caminho/para/seus/modelos/InimigoEsqueleto.tscn",
\t\t\t"res://caminho/para/seus/modelos/InimigoMorcego.tscn",
\t\t\t"res://caminho/para/seus/modelos/InimigoSlime.tscn"
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

# Posições fixas para formação (Ajuste conforme sua câmera)
var hero_positions = [Vector3(-2, 0, 0), Vector3(-4, 0, 2), Vector3(-4, 0, -2)]
# Até 6 inimigos em 2 fileiras
var enemy_positions = [Vector3(2, 0, 0), Vector3(4, 0, 2), Vector3(4, 0, -2), Vector3(3, 0, 4), Vector3(5, 0, 0), Vector3(3, 0, -4)]

func _ready():
\trandomize()
\t# Gera a cena logo no frame 1 para o Movie Maker já gravar
\tgenerate_take()

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
\t\t# AQUI VOCÊ SINALIZARIA PARA A CÂMERA E PARA O ANIMATION PLAYER INICIAREM O TAKE
\t\t# ex: start_combat_action(attacker, target)

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
"""
with open("TrailerDirector.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("TrailerDirector.gd created successfully with tag: [file-tag: TrailerDirector-xxxxxxxxxx]")