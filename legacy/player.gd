extends CharacterBody3D

# --- SELEÇÃO DE PERSONAGEM NO EDITOR ---
# Adicione os nomes dos seus personagens aqui para aparecerem no dropdown do Inspector
@export_enum("Knight", "Robot", "Shaman") var personagem_selecionado: String = "Knight"

# --- CATÁLOGO DE CONFIGURAÇÃO DOS MODELOS ---
# rotacao: Graus no eixo Y para alinhar a frente do modelo com o -Z da Godot
# altura_mesh: Offset Y para subir ou descer a malha caso o pivô esteja fora do pé
# altura_colisor: Altura total da caixa/cápsula de colisão
# largura_colisor: Largura total (ou diâmetro) da colisão
const CATALOGO_PERSONAGENS = {
	"Knight": {
		"modelo": preload("res://assets/models/knight_standing/knightStandingColored.glb"), # Funciona com .glb, .tscn ou .obj
		"rotacao": 90.0,
		"altura_mesh": 0.1,
		"altura_colisor": 1.5,
		"largura_colisor": 0.6
	},
	"Robot": {
		"modelo": preload("res://assets/models/robot/robot.tscn"),
		"rotacao": 180.0,
		"altura_mesh": 0.125,
		"altura_colisor": 1.1,
		"largura_colisor": 0.8
	},
	"Shaman": {
		"modelo": preload("res://assets/models/shaman/shaman.glb"),
		"rotacao": 180.0,
		"altura_mesh": 0.15,
		"altura_colisor": 1.3,
		"largura_colisor": 0.5
	}
}

# --- VARIÁVEIS DE FÍSICA E CÂMERA ---
@export var velocidade: float = 5.0
@export var mouse_sensibilidade: float = 0.005
@export var forca_pulo: float = 5.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	configurar_personagem(personagem_selecionado)

func configurar_personagem(nome: String):
	if not CATALOGO_PERSONAGENS.has(nome):
		push_error("Personagem não encontrado no catálogo: " + nome)
		return
		
	var cfg = CATALOGO_PERSONAGENS[nome]
	
	# 1. Limpa qualquer modelo anterior dentro de Visuals
	for child in $Visuals.get_children():
		child.queue_free()
		
	# 2. Instancia o novo modelo (suporta PackedScene como .glb/.tscn e Mesh como .obj)
	var recurso = cfg["modelo"]
	var instancia_modelo: Node3D = null
	
	if recurso is PackedScene:
		instancia_modelo = recurso.instantiate()
	elif recurso is Mesh:
		var mesh_node = MeshInstance3D.new()
		mesh_node.mesh = recurso
		instancia_modelo = mesh_node
		
	if instancia_modelo:
		$Visuals.add_child(instancia_modelo)
		# Aplica o offset de rotação e de altura diretamente no modelo filho!
		instancia_modelo.rotation_degrees.y = cfg["rotacao"]
		instancia_modelo.position.y = cfg["altura_mesh"]
		
	# 3. Configura a Altura e Largura do Colisor
	var col_node: CollisionShape3D = $CollisionShape3D
	var alt_col: float = cfg["altura_colisor"]
	var larg_col: float = cfg["largura_colisor"]
	
	# Duplica o shape para garantir que a edição seja única desta instância
	if col_node.shape:
		col_node.shape = col_node.shape.duplicate()
		
	if col_node.shape is CapsuleShape3D:
		col_node.shape.height = alt_col
		col_node.shape.radius = larg_col / 2.0
	elif col_node.shape is BoxShape3D:
		col_node.shape.size = Vector3(larg_col, alt_col, larg_col)
	elif col_node.shape is CylinderShape3D:
		col_node.shape.height = alt_col
		col_node.shape.radius = larg_col / 2.0
		
	# Alinha a base do colisor exatamente no chão (Y = 0)
	col_node.position.y = alt_col / 2.0
	
	# 4. Ajusta a altura do pivô da câmera proporcionalmente à altura do colisor
	if has_node("CameraPivot"):
		$CameraPivot.position.y = alt_col * 0.85

func _input(event):
	if event is InputEventMouseMotion:
		$CameraPivot.rotate_y(-event.relative.x * mouse_sensibilidade)
		var spring_arm = $CameraPivot/SpringArm3D
		spring_arm.rotate_x(-event.relative.y * mouse_sensibilidade)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2, PI/4)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = forca_pulo

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

	move_and_slide()
