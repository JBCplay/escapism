extends CharacterBody3D

@export var velocidade: float = 5.0
@export var mouse_sensibilidade: float = 0.005
@export var forca_pulo: float = 5.0

# Pega a gravidade padrão das configurações do projeto Godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Trava e esconde o cursor do mouse no centro da tela
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		$CameraPivot.rotate_y(-event.relative.x * mouse_sensibilidade)
		
		var spring_arm = $CameraPivot/SpringArm3D
		spring_arm.rotate_x(-event.relative.y * mouse_sensibilidade)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2, PI/4)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	# 1. Aplica Gravidade quando o Boxxie estiver no ar
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# --- LÓGICA DE PULO ---
	# Usa "ui_accept", que por padrão no Godot inclui a tecla Espaço (Spacebar).
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = forca_pulo
	
	# 2. Leitura de Controles WASD
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir != Vector2.ZERO:
		var camera_rot_y = $CameraPivot.rotation.y
		var direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, camera_rot_y).normalized()
		
		velocity.x = direction.x * velocidade
		velocity.z = direction.z * velocidade
		
		var angulo_frente = atan2(-direction.x, -direction.z)
		$Visuals.rotation.y = lerp_angle($Visuals.rotation.y, angulo_frente, 0.15)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidade)
		velocity.z = move_toward(velocity.z, 0, velocidade)

	# move_and_slide faz a física funcionar contra colisores!
	move_and_slide()
