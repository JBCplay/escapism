extends Node3D

@onready var cam_wide = $Cam_Wide
@onready var cam_action = $Cam_Hero_Action
@onready var cam_impact = $Cam_Enemy_Impact

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

func _ready(): 
	focus_wide()

func _process(delta): 
	if shake_duration > 0 and active_shake_camera:
		shake_duration -= delta 
		active_shake_camera.h_offset = original_h_offset + randf_range(-shake_intensity, shake_intensity)
		active_shake_camera.v_offset = original_v_offset + randf_range(-shake_intensity, shake_intensity)
		
	elif active_shake_camera: 
		active_shake_camera.h_offset = original_h_offset
		active_shake_camera.v_offset = original_v_offset
		active_shake_camera = null

func focus_wide():
	cam_wide.current = true
	
func focus_action(attacker: Node3D, target_node: Node3D): 
	var is_attacker_hero = attacker.get_parent().name == "Heroes"
	var hero = attacker if is_attacker_hero else target_node
	var enemy = target_node if is_attacker_hero else attacker
	
	var hero_pos = hero.global_position + Vector3(0, 1.5, 0)
	var enemy_pos = enemy.global_position + Vector3(0, 1.5, 0)
	
	var dir_to_enemy = (enemy_pos - hero_pos).normalized()
	var right_dir = dir_to_enemy.cross(Vector3.UP).normalized()
	
	var scale_mult = max(get_model_scale_multiplier(hero), get_model_scale_multiplier(enemy))
	var distance = hero_pos.distance_to(enemy_pos)
	
	# AUMENTADO: Recuo base subiu de 3.5 para 4.0, lateral de 2.5 para 3.2 e altura de 1.0 para 1.4
	cam_action.global_position = hero_pos - (dir_to_enemy * (3.5 * scale_mult + distance * 0.35)) + (right_dir * (3.2 * scale_mult)) + Vector3(0, 1.4 * scale_mult, 0)
	
	var midpoint = hero_pos.lerp(enemy_pos, 0.5)
	cam_action.look_at(midpoint, Vector3.UP)
	
	cam_action.rotation_degrees.z = 0.0
	cam_action.current = true
	
func focus_impact(target_node: Node3D, attacker: Node3D): 
	var is_attacker_hero = attacker.get_parent().name == "Heroes"
	var hero = attacker if is_attacker_hero else target_node
	var enemy = target_node if is_attacker_hero else attacker
	
	var hero_pos = hero.global_position + Vector3(0, 1.5, 0)
	var enemy_pos = enemy.global_position + Vector3(0, 1.5, 0)
	
	var dir_to_enemy = (enemy_pos - hero_pos).normalized()
	var right_dir = dir_to_enemy.cross(Vector3.UP).normalized()
	
	var scale_mult = max(get_model_scale_multiplier(hero), get_model_scale_multiplier(enemy))
	
	# AUMENTADO: Recuo no impacto subiu de 3.0 para 4.5, lateral de 2.0 para 2.8 e altura de 0.5 para 1.0
	cam_impact.global_position = hero_pos - (dir_to_enemy * (3.0 * scale_mult)) + (right_dir * (2.8 * scale_mult)) + Vector3(0, 1.0 * scale_mult, 0)
	
	var midpoint = hero_pos.lerp(enemy_pos, 0.5)
	cam_impact.look_at(midpoint, Vector3.UP)
	
	cam_impact.rotation_degrees.z = 0.0
	cam_impact.current = true
	
# Calcula o tamanho real da malha para afastar a câmera
func get_model_scale_multiplier(actor: Node3D) -> float:
	var mesh_instance = _find_mesh_recursive(actor)
	if mesh_instance and mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		var max_axis = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		
		var global_scale = mesh_instance.global_transform.basis.get_scale().y
		var real_size = max_axis * global_scale
		
		# ALTERADO: O limite mínimo subiu de 0.5 para 1.0 (impede que modelos pequenos puxem a câmera para perto demais)
		return clamp(real_size / 2.0, 1.0, 3.0)
		
	return 1.0

func play_hit_effect(target: Node3D, element: String, is_crit: bool, attacker: Node3D):
	focus_impact(target, attacker)
	
	var shake_intensity = 0.4 if is_crit else 0.15
	var shake_time = 0.3 if is_crit else 0.2
	var hit_stop_time = 0.3 if is_crit else 0.15
	
	trigger_screen_shake(cam_impact, shake_intensity, shake_time)
	shake_model(target, shake_intensity * 1.5, shake_time) 
	
	apply_hit_stop(hit_stop_time)
	flash_red(target)

	if vfx_scenes.has(element) and vfx_scenes[element] != null:
		var vfx_instance = vfx_scenes[element].instantiate()
		target.add_child(vfx_instance)
		vfx_instance.position = Vector3(0, 1.0, 0) 
		
	if is_crit and vfx_scenes.has("critico") and vfx_scenes["critico"] != null:
		var crit_instance = vfx_scenes["critico"].instantiate()
		target.add_child(crit_instance)
		crit_instance.position = Vector3(0, 1.2, 0) 
		crit_instance.scale = Vector3(1.5, 1.5, 1.5)

func apply_hit_stop(duration_seconds: float): 
	await get_tree().create_timer(duration_seconds, true, false, true).timeout 
	Engine.time_scale = 1.0

func trigger_screen_shake(camera: Camera3D, intensity: float, duration: float):
	active_shake_camera = camera
	shake_intensity = intensity
	shake_duration = duration
	original_h_offset = camera.h_offset
	original_v_offset = camera.v_offset
	
func flash_red(target: Node3D): 
	var mesh_instance = _find_mesh_recursive(target)
	if mesh_instance and mesh_instance.mesh:
		var flash_material = StandardMaterial3D.new()
		flash_material.albedo_color = Color.RED
		flash_material.emission_enabled = true
		flash_material.emission = Color.RED
		
		var old_materials = []
		for i in range(mesh_instance.mesh.get_surface_count()):
			old_materials.append(mesh_instance.get_surface_override_material(i))
			mesh_instance.set_surface_override_material(i, flash_material)
		
		await get_tree().create_timer(0.1, true, false, true).timeout
		
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

func shake_model(target: Node3D, intensity: float, duration: float):
	var original_pos = target.position
	var tween = create_tween()
	
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	var shake_steps = 6
	var step_time = duration / shake_steps
	
	for i in range(shake_steps):
		var random_offset = Vector3(
			randf_range(-intensity, intensity), 
			0, 
			randf_range(-intensity, intensity)
		)
		tween.tween_property(target, "position", original_pos + random_offset, step_time)
	
	tween.tween_property(target, "position", original_pos, step_time)
