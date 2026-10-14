code = """extends Node3D

@onready var cam_wide = $Cam_Wide
@onready var cam_action = $Cam_Hero_Action
@onready var cam_impact = $Cam_Enemy_Impact

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var original_h_offset: float = 0.0
var original_v_offset: float = 0.0
var active_shake_camera: Camera3D = null

var vfx_scenes = {
\t"fogo": preload("res://Trailer/CombatScene/VfxFogo.tscn"),
\t"raio": preload("res://Trailer/CombatScene/VfxRaio.tscn"),
\t"trevas": preload("res://Trailer/CombatScene/VfxTrevas.tscn"),
\t"agua": preload("res://Trailer/CombatScene/VfxAgua.tscn"),
\t"critico": preload("res://Trailer/CombatScene/VfxCritico.tscn")
}

func _ready(): 
\tfocus_wide()

func _process(delta): 
\tif shake_duration > 0 and active_shake_camera:
\t\tshake_duration -= delta 
\t\tactive_shake_camera.h_offset = original_h_offset + randf_range(-shake_intensity, shake_intensity)
\t\tactive_shake_camera.v_offset = original_v_offset + randf_range(-shake_intensity, shake_intensity)
\t\t
\telif active_shake_camera: 
\t\tactive_shake_camera.h_offset = original_h_offset
\t\tactive_shake_camera.v_offset = original_v_offset
\t\tactive_shake_camera = null

#--- FUNÇÕES DE CORTE DE CÂMERA (AGORA DINÂMICAS) ---
func focus_wide():
\tcam_wide.current = true
\t
func focus_action(attacker: Node3D): 
\t# Pega a posição do alvo criado no TrailerDirector
\tvar target = attacker.get_node_or_null("CamTarget")
\tvar focus_pos = target.global_position if target else attacker.global_position + Vector3(0, 1.5, 0)
\t
\t# Coloca a câmera nas costas do personagem, levemente de lado (Dutch Angle dramático)
\tvar forward_dir = -attacker.global_transform.basis.z.normalized()
\tvar right_dir = attacker.global_transform.basis.x.normalized()
\t
\t# Posição: 2 metros para trás, 1 metro para a direita, levemente para cima
\tcam_action.global_position = focus_pos - (forward_dir * 2.0) + (right_dir * 1.0) + Vector3(0, 0.5, 0)
\tcam_action.look_at(focus_pos, Vector3.UP)
\t
\t# Inclinação de Persona
\tcam_action.rotation_degrees.z = -10.0
\t
\tcam_action.current = true
\t
func focus_impact(target_node: Node3D): 
\tvar target_marker = target_node.get_node_or_null("CamTarget")
\tvar focus_pos = target_marker.global_position if target_marker else target_node.global_position + Vector3(0, 1.5, 0)
\t
\t# Câmera de impacto fica BEM perto do rosto do inimigo, olhando de baixo pra cima
\tvar forward_dir = -target_node.global_transform.basis.z.normalized()
\tvar right_dir = target_node.global_transform.basis.x.normalized()
\t
\tcam_impact.global_position = focus_pos + (forward_dir * 1.5) - (right_dir * 1.0) - Vector3(0, 0.5, 0)
\tcam_impact.look_at(focus_pos, Vector3.UP)
\t
\t# Inclinação contrária para o impacto
\tcam_impact.rotation_degrees.z = 15.0
\t
\tcam_impact.current = true

#--- EFEITOS ESPECIAIS ---
func play_hit_effect(target: Node3D, element: String, is_crit: bool):
\tfocus_impact(target)
\t
\tvar shake_intensity = 0.4 if is_crit else 0.15
\tvar shake_time = 0.3 if is_crit else 0.2
\tvar hit_stop_time = 0.3 if is_crit else 0.15
\t
\ttrigger_screen_shake(cam_impact, shake_intensity, shake_time)
\tshake_model(target, shake_intensity * 1.5, shake_time) 
\t
\tapply_hit_stop(hit_stop_time)
\tflash_red(target)

\tif vfx_scenes.has(element) and vfx_scenes[element] != null:
\t\tvar vfx_instance = vfx_scenes[element].instantiate()
\t\ttarget.add_child(vfx_instance)
\t\tvfx_instance.position = Vector3(0, 1.0, 0) 
\t\t
\tif is_crit and vfx_scenes.has("critico") and vfx_scenes["critico"] != null:
\t\tvar crit_instance = vfx_scenes["critico"].instantiate()
\t\ttarget.add_child(crit_instance)
\t\tcrit_instance.position = Vector3(0, 1.2, 0) 
\t\tcrit_instance.scale = Vector3(1.5, 1.5, 1.5)

func apply_hit_stop(duration_seconds: float): 
\tawait get_tree().create_timer(duration_seconds, true, false, true).timeout 
\tEngine.time_scale = 1.0

func trigger_screen_shake(camera: Camera3D, intensity: float, duration: float):
\tactive_shake_camera = camera
\tshake_intensity = intensity
\tshake_duration = duration
\toriginal_h_offset = camera.h_offset
\toriginal_v_offset = camera.v_offset
\t
func flash_red(target: Node3D): 
\tvar mesh_instance = _find_mesh_recursive(target)
\tif mesh_instance and mesh_instance.mesh:
\t\tvar flash_material = StandardMaterial3D.new()
\t\tflash_material.albedo_color = Color.RED
\t\tflash_material.emission_enabled = true
\t\tflash_material.emission = Color.RED
\t\t
\t\tvar old_materials = []
\t\tfor i in range(mesh_instance.mesh.get_surface_count()):
\t\t\told_materials.append(mesh_instance.get_surface_override_material(i))
\t\t\tmesh_instance.set_surface_override_material(i, flash_material)
\t\t
\t\tawait get_tree().create_timer(0.1, true, false, true).timeout
\t\t
\t\tfor i in range(mesh_instance.mesh.get_surface_count()):
\t\t\tmesh_instance.set_surface_override_material(i, old_materials[i])

func _find_mesh_recursive(node: Node) -> MeshInstance3D:
\tif node is MeshInstance3D:
\t\treturn node
\t
\tfor child in node.get_children():
\t\tvar result = _find_mesh_recursive(child)
\t\tif result:
\t\t\treturn result
\t
\treturn null

func shake_model(target: Node3D, intensity: float, duration: float):
\tvar original_pos = target.position
\tvar tween = create_tween()
\t
\ttween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
\t
\tvar shake_steps = 6
\tvar step_time = duration / shake_steps
\t
\tfor i in range(shake_steps):
\t\tvar random_offset = Vector3(
\t\t\trandf_range(-intensity, intensity), 
\t\t\t0, 
\t\t\trandf_range(-intensity, intensity)
\t\t)
\t\ttween.tween_property(target, "position", original_pos + random_offset, step_time)
\t
\ttween.tween_property(target, "position", original_pos, step_time)
"""
with open("camera_controler_3.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("camera_controler_3.gd created successfully with tag: [file-tag: camera_controler_3-xxxxxxxxxx]")