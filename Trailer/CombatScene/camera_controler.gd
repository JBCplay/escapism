extends Node3D

@onready var cam_wide = $Cam_Wide
@onready var cam_action = $Cam_Hero_Action
@onready var cam_impact = $Cam_Enemy_Impact

#Variáveis para o Screen Shake
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var original_h_offset: float = 0.0
var original_v_offset: float = 0.0
var active_shake_camera: Camera3D = null

func _ready(): # Garante que começamos com a visão geral
	focus_wide()

func _process(delta): # Lógica do Screen Shake aplicada a cada frame
	if shake_duration > 0 and active_shake_camera:
		shake_duration -= delta # Gera offsets aleatórios baseados na intensidade
		active_shake_camera.h_offset = original_h_offset + randf_range(-shake_intensity, shake_intensity)
		active_shake_camera.v_offset = original_v_offset + randf_range(-shake_intensity, shake_intensity)
		
	elif active_shake_camera: # Restaura os offsets originais quando o tremor acaba
		active_shake_camera.h_offset = original_h_offset
		active_shake_camera.v_offset = original_v_offset
		active_shake_camera = null

#--- FUNÇÕES DE CORTE DE CÂMERA ---
func focus_wide():
	cam_wide.current = true
	
func focus_action(attacker: Node3D): # Opcional: Aqui você pode reposicionar a cam_action para ficar # nas costas do atacante atual antes de ativá-la. 
	cam_action.current = true
	
func focus_impact(target: Node3D): # Opcional: Aqui você pode reposicionar a cam_impact para focar # no rosto/corpo do alvo atual antes de ativá-la.
	cam_impact.current = true

#--- EFEITOS ESPECIAIS ---
func play_hit_effect(target: Node3D, do_screen_shake: bool = true):
	focus_impact(target)
	if do_screen_shake:
		trigger_screen_shake(cam_impact, 0.15, 0.2)

	# Efeito "Persona": Congela o tempo brevemente
	apply_hit_stop(0.15)

	# Faz o alvo piscar em vermelho (Assumindo que o modelo tem um MeshInstance3D filho)
	flash_red(target)

func apply_hit_stop(duration_seconds: float): # Desacelera o jogo quase parando Engine.time_scale = 0.05
# Cria um timer que ignora a escala de tempo do jogo (process_always = true)
	await get_tree().create_timer(duration_seconds, true, false, true).timeout 

	# Restaura a velocidade normal
	Engine.time_scale = 1.0

func trigger_screen_shake(camera: Camera3D, intensity: float, duration: float):
	active_shake_camera = camera
	shake_intensity = intensity
	shake_duration = duration
	original_h_offset = camera.h_offset
	original_v_offset = camera.v_offset
	
func flash_red(target: Node3D): # Procura o primeiro MeshInstance3D dentro do alvo
	var mesh_instance = _find_mesh_recursive(target)
	if mesh_instance and mesh_instance.mesh:
		# Cria um material vermelho temporário
		var flash_material = StandardMaterial3D.new()
		flash_material.albedo_color = Color.RED
		flash_material.emission_enabled = true
		flash_material.emission = Color.RED
		
		# Salva os materiais antigos e aplica o vermelho
		var old_materials = []
		for i in range(mesh_instance.mesh.get_surface_count()):
			old_materials.append(mesh_instance.get_surface_override_material(i))
			mesh_instance.set_surface_override_material(i, flash_material)
		
		# Espera um décimo de segundo ignorando o hit_stop
		await get_tree().create_timer(0.1, true, false, true).timeout
		
		# Restaura os materiais originais
		for i in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(i, old_materials[i])

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = _find_mesh_recursive(child)
		if result:
			return result
	
	return null
