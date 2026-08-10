extends CharacterBody3D

@export var velocidade: float = 5.0
@export var mouse_sensibilidade: float = 0.005

func _ready():
	# Trava e esconde o cursor do mouse no centro da tela do jogo
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Se o jogador mover o mouse, gira o pivô da câmera
	if event is InputEventMouseMotion:
		# Gira horizontalmente (Esquerda/Direita)
		$CameraPivot.rotate_y(-event.relative.x * mouse_sensibilidade)
		
		# Gira verticalmente (Cima/Baixo) no SpringArm, limitando o ângulo
		var spring_arm = $CameraPivot/SpringArm3D
		spring_arm.rotate_x(-event.relative.y * mouse_sensibilidade)
		
		# Limita a câmera para não dar "cambalhotas" (entre -90 e 45 graus)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2, PI/4)

	# Aperte ESC para liberar o mouse e poder fechar a janela
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(_delta):
	# Captura entrada WASD / Setas do teclado
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir != Vector2.ZERO:
		# Ajusta a direção do movimento para ser relativa a para onde a Câmera está olhando
		var camera_rot_y = $CameraPivot.rotation.y
		var direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, camera_rot_y).normalized()
		
		velocity.x = direction.x * velocidade
		velocity.z = direction.z * velocidade
		
		# Aponta o corpinho do Boxxie (o nariz de cenoura) para a direção da caminhada
		var angulo_frente = atan2(-direction.x, -direction.z)
		$Visuals.rotation.y = lerp_angle($Visuals.rotation.y, angulo_frente, 0.15)
	else:
		# Desaceleração suave quando solta as teclas
		velocity.x = move_toward(velocity.x, 0, velocidade)
		velocity.z = move_toward(velocity.z, 0, velocidade)

	move_and_slide()
