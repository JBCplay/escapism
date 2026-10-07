extends Node

var battle_scene: PackedScene = preload("res://scenes/battle/Battle.tscn")
var overworld_ref: Node = null
var current_battle_instance: Node = null

func iniciar_combate(inimigo_data: Resource) -> void:
	# 1. Intercepta e pausa a exploração
	overworld_ref = get_tree().current_scene
	if overworld_ref:
		overworld_ref.process_mode = Node.PROCESS_MODE_DISABLED
	
	# 2. Altera o estado primário
	GameManager.change_state(GameManager.GameState.COMBAT)
	
	# 3. Injeta o ambiente de combate fechado na Scene Tree
	current_battle_instance = battle_scene.instantiate()
	get_tree().root.add_child(current_battle_instance)
	
	# 4. Passa as referências de dados
	if current_battle_instance.has_method("setup_battle"):
		current_battle_instance.setup_battle(PartyManager.equipe_ativa, inimigo_data)

func encerrar_combate(vitoria: bool) -> void:
	# 1. Remove a cena de batalha da memória
	if current_battle_instance:
		current_battle_instance.queue_free()
		current_battle_instance = null
		
	# 2. Retoma o processamento do overworld
	if overworld_ref:
		overworld_ref.process_mode = Node.PROCESS_MODE_INHERIT
		
	# 3. Retorno seguro ao mapa
	GameManager.change_state(GameManager.GameState.EXPLORATION)
