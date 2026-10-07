extends CharacterBody3D

const SPEED = 5.0
var player_target = null # Preencha isso com a referência do seu jogador
var in_combat = false

@onready var visual_pivot = $PivotVisual
@onready var battle_trigger = $BattleTrigger

func _ready():
	# Conecta o sinal de detecção da Area3D via código
	battle_trigger.body_entered.connect(_on_player_detected)

func _physics_process(delta):
	if in_combat or not player_target:
		return

	# 1. Movimentação Livre e Colisão com Paredes/Chão
	var direction = (player_target.global_position - global_position).normalized()
	direction.y = 0 # Mantém o movimento no plano horizontal
	
	velocity = direction * SPEED
	
	# Aplica gravidade se não estiver no chão
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide() # Esta função nativa impede que ele atravesse as paredes do cenário

	# 2. Ilusão de Rolamento Matemático
	if velocity.length() > 0.1:
		# Descobre qual é o eixo de rotação cruzando o vetor CIMA com a direção do movimento
		var rotation_axis = Vector3.UP.cross(direction).normalized()
		
		# Rotaciona o Pivot visual. A velocidade do giro é proporcional à velocidade de movimento
		visual_pivot.rotate(rotation_axis, SPEED * delta)

func _on_player_detected(body):
	# Verifica se quem entrou na Area3D foi o jogador (usando Groups da Godot)
	if body.is_in_group("Player") and not in_combat:
		in_combat = true
		initiate_turn_based_battle()

func initiate_turn_based_battle():
	# Pausa a movimentação no overworld
	set_physics_process(false)
	
	# Efeito de "Alerta" antes da transição
	visual_pivot.scale = Vector3(1.2, 1.2, 1.2) # O cubo incha brevemente
	
	print("Contato feito! Transição estilo Persona iniciada.")
	
	# Aqui você chama o seu gerenciador de cena para congelar o mundo 
	# e carregar a UI/Cena de batalha por turnos.
	# Exemplo: SceneManager.load_battle_scene(enemy_stats)
