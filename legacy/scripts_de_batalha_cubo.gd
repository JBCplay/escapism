extends Node3D

@onready var mesh_instance = $PivotVisual/MeshInstance3D # Arraste o seu CuboEsculpido.obj para cá

func _ready():
	_setup_materials()

func _setup_materials():
	# 1. Cria o material da Pedra Escura Fosca
	var mat_stone = StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.08, 0.08, 0.08) # Quase preto
	mat_stone.roughness = 1.0 # Totalmente áspero
	mat_stone.metallic = 0.0

	# 2. Cria o material Vermelho Neon Emissivo
	var mat_neon = StandardMaterial3D.new()
	mat_neon.albedo_color = Color(0, 0, 0)
	mat_neon.emission_enabled = true
	mat_neon.emission = Color(1.0, 0.0, 0.1) # Vermelho vivo
	mat_neon.emission_energy_multiplier = 8.0 # Intensidade do brilho

	# 3. Aplica automaticamente no seu arquivo .obj
	# O nosso .obj tem 7 partes. O índice 0 é o núcleo neon, os índices de 1 a 6 são a armadura.
	if mesh_instance.mesh:
		mesh_instance.set_surface_override_material(0, mat_neon)
		for i in range(1, 7):
			mesh_instance.set_surface_override_material(i, mat_stone)

# ==========================================
# ANIMAÇÕES DE ATAQUE (TWEENS)
# ==========================================

func attack_roll(target_position: Vector3):
	# Calcula a distância para saber quantas vezes o cubo precisa girar
	var distance = global_position.distance_to(target_position)
	var roll_angles = (distance / 8.0) * (PI / 2.0) * 4.0 # Roda proporcional ao tamanho do cubo
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Move para o alvo
	tween.tween_property(self, "global_position", target_position, 1.0)
	# Rola o eixo X simultaneamente
	tween.tween_property($PivotVisual, "rotation:x", roll_angles, 1.0)
	
	tween.chain().tween_callback(_on_attack_finished)

func attack_jump(target_position: Vector3):
	var tween = create_tween()
	
	# 1. Antecipação: O cubo se espreme no chão
	tween.tween_property($PivotVisual, "scale", Vector3(1.2, 0.7, 1.2), 0.2).set_trans(Tween.TRANS_SINE)
	
	# 2. O Salto
	var jump_tween = create_tween().set_parallel(true)
	jump_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Sobe no eixo Y (Metade do tempo)
	jump_tween.tween_property(self, "global_position:y", global_position.y + 6.0, 0.4)
	# Move na direção do alvo (Tempo total)
	jump_tween.tween_property(self, "global_position:x", target_position.x, 0.8)
	jump_tween.tween_property(self, "global_position:z", target_position.z, 0.8)
	# Rotação caótica e agressiva no ar
	jump_tween.tween_property($PivotVisual, "rotation", Vector3(PI * 4, PI * 2, PI * 3), 0.8)
	jump_tween.tween_property($PivotVisual, "scale", Vector3(1, 1, 1), 0.2)
	
	# 3. A Queda (Acelera para baixo)
	var fall_tween = create_tween()
	fall_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(self, "global_position:y", target_position.y, 0.4)
	
	# 4. Impacto: Tremor rápido e volta à escala normal
	fall_tween.tween_property($PivotVisual, "scale", Vector3(1.4, 0.5, 1.4), 0.1)
	fall_tween.tween_property($PivotVisual, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
	
	fall_tween.tween_callback(_on_attack_finished)

func _on_attack_finished():
	print("Ataque finalizado! Voltar para a posição original ou passar o turno.")
	# Zera a rotação para os próximos cálculos não quebrarem
	$PivotVisual.rotation = Vector3.ZERO
