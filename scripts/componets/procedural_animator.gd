extends Node
class_name ProceduralAnimator

@export var root_node: Node3D  # O nó principal do personagem que viaja pelo mapa
@export var model_node: Node3D # A malha/visual que vai pular e balançar

# Parâmetros de ajuste
@export var walk_speed: float = 15.0
@export var bob_height: float = 0.2
@export var sway_angle: float = 0.1

var is_walking: bool = false
var time_passed: float = 0.0
var original_model_pos: Vector3

func _ready():
	if model_node:
		original_model_pos = model_node.position

func _process(delta):
	if not model_node: return
	
	if is_walking:
		time_passed += delta
		# Pulo constante (bobbing) usando valor absoluto do seno
		model_node.position.y = original_model_pos.y + abs(sin(time_passed * walk_speed)) * bob_height
		# Balanço lateral (wobble)
		model_node.rotation.z = sin(time_passed * walk_speed * 0.5) * sway_angle
	else:
		# Retorna suavemente ao estado de repouso quando para de andar
		model_node.position.y = lerp(model_node.position.y, original_model_pos.y, delta * 10.0)
		model_node.rotation.z = lerp(model_node.rotation.z, 0.0, delta * 10.0)

# --- FUNÇÕES PÚBLICAS PARA SEREM CHAMADAS POR OUTROS SCRIPTS ---

# Usado tanto na exploração quanto no combate
func move_to(destination: Vector3, duration: float) -> Tween:
	is_walking = true
	var tween = create_tween()
	# Move o nó raiz até o destino
	tween.tween_property(root_node, "global_position", destination, duration)
	# Desliga a animação de caminhada ao chegar
	tween.tween_callback(func(): is_walking = false)
	return tween

# Usado no combate (ou na exploração ao quebrar um obstáculo)
func attack_dash(target_pos: Vector3, impact_callback: Callable) -> Tween:
	var tween = create_tween()
	var start_pos = root_node.global_position
	
	# 1. Avança rápido em direção ao alvo (parando um pouco antes para não entrar no modelo)
	var attack_position = target_pos.move_toward(start_pos, 1.5)
	tween.tween_property(root_node, "global_position", attack_position, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# 2. Chama a função de impacto exatemente no momento que o avanço termina
	tween.tween_callback(impact_callback)
	
	# 3. Fica parado um instante (O hit-stop do seu controlador de câmera vai afetar isso)
	tween.tween_interval(0.2)
	
	# 4. Retorna para a posição original
	tween.tween_property(root_node, "global_position", start_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	return tween
