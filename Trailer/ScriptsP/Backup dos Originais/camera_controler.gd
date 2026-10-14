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

var vfx_scenes = {
	"fogo": preload("res://Trailer/CombatScene/VfxFogo.tscn"),
	"raio": preload("res://Trailer/CombatScene/VfxRaio.tscn"),
	"trevas": preload("res://Trailer/CombatScene/VfxTrevas.tscn"),
	"agua": preload("res://Trailer/CombatScene/VfxAgua.tscn"),
	"critico": preload("res://Trailer/CombatScene/VfxCritico.tscn")
}

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
func play_hit_effect(target: Node3D, element: String, is_crit: bool):
	focus_impact(target)
	
	var shake_intensity = 0.4 if is_crit else 0.15
	var shake_time = 0.3 if is_crit else 0.2
	var hit_stop_time = 0.3 if is_crit else 0.15
	
	# Tremor da câmera
	trigger_screen_shake(cam_impact, shake_intensity, shake_time)
	# Tremor do próprio modelo (O novo "Knockback")
	shake_model(target, shake_intensity * 1.5, shake_time) 
	
	apply_hit_stop(hit_stop_time)
	flash_red(target)

	# Instancia a partícula elemental
	if vfx_scenes.has(element) and vfx_scenes[element] != null:
		var vfx_instance = vfx_scenes[element].instantiate()
		target.add_child(vfx_instance)
		vfx_instance.position = Vector3(0, 1.0, 0) 
		
	# Instancia a partícula de CRÍTICO por cima do elemento
	if is_crit and vfx_scenes.has("critico") and vfx_scenes["critico"] != null:
		var crit_instance = vfx_scenes["critico"].instantiate()
		target.add_child(crit_instance)
		crit_instance.position = Vector3(0, 1.2, 0) # Levemente mais alto que o elemento
		# Se quiser, aumente a escala da partícula para cobrir o modelo
		crit_instance.scale = Vector3(1.5, 1.5, 1.5)

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

# 3. ADICIONE ESTA NOVA FUNÇÃO NO FINAL DO SCRIPT
func shake_model(target: Node3D, intensity: float, duration: float):
	var original_pos = target.position
	var tween = create_tween()
	
	# Como o hit-stop afeta o tempo global, nós forçamos o Tween a ignorar a escala de tempo
	# para que o modelo trema furiosamente mesmo em "câmera lenta"
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	var shake_steps = 6
	var step_time = duration / shake_steps
	
	# Cria uma sequência de movimentos aleatórios rápidos
	for i in range(shake_steps):
		var random_offset = Vector3(
			randf_range(-intensity, intensity), 
			0, # Mantemos Y em 0 para ele não afundar no chão
			randf_range(-intensity, intensity)
		)
		tween.tween_property(target, "position", original_pos + random_offset, step_time)
	
	# O último passo SEMPRE retorna para a posição exata original
	tween.tween_property(target, "position", original_pos, step_time)
