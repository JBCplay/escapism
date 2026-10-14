extends CanvasLayer

# Arraste o seu nó Button para cá no inspetor, ou use o caminho direto:
@onready var attack_button = $AttackButton

func _ready():
	# Esconde o botão logo no início por precaução
	if attack_button:
		attack_button.hide()
		
		# --- ESTILIZAÇÃO DO BOTÃO VIA CÓDIGO ---
		# Remove a borda/fundo cinza padrão e cria um botão vermelho vivo
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color("d62828") # Vermelho vibrante
		style_normal.corner_radius_top_left = 8
		style_normal.corner_radius_top_right = 8
		style_normal.corner_radius_bottom_left = 8
		style_normal.corner_radius_bottom_right = 8
		# Uma leve sombra pra dar destaque
		style_normal.shadow_color = Color(0, 0, 0, 0.5)
		style_normal.shadow_size = 4
		style_normal.shadow_offset = Vector2(0, 4)
		
		attack_button.add_theme_stylebox_override("normal", style_normal)
		attack_button.add_theme_stylebox_override("hover", style_normal)
		attack_button.add_theme_stylebox_override("pressed", style_normal)
		attack_button.add_theme_stylebox_override("focus", style_normal)
		
		# Deixa o texto em negrito, branco e maior
		attack_button.add_theme_color_override("font_color", Color.WHITE)
		attack_button.add_theme_font_size_override("font_size", 24)
		
		# Posiciona no canto inferior esquerdo com um bom espaçamento
		# (Considerando uma resolução base de 1920x1080)
		attack_button.custom_minimum_size = Vector2(200, 60)
		attack_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		attack_button.position = Vector2(50, -110) # 50px da esquerda, 110px do fundo
		
		# Garante que o pivô de escala seja no centro do botão, 
		# para que ele cresça para todos os lados e não apenas para a direita/baixo
		attack_button.pivot_offset = attack_button.size / 2

# Chamado pelo TrailerDirector antes da gravação (logo após definir quem ataca)
func setup_ui(is_hero_attacking: bool):
	if not attack_button: return
	
	if is_hero_attacking:
		attack_button.show()
	else:
		attack_button.hide()

# Chamado no exato momento em que o ataque acontece (junto com o Screen Shake)
func animate_press():
	if not attack_button or not attack_button.visible:
		return

	var tween = create_tween()
	
	# 1. Cresce um pouco rápido (efeito de clique/impacto)
	tween.tween_property(attack_button, "scale", Vector2(1.15, 1.15), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Deixa o botão mais brilhante por uma fração de segundo
	tween.parallel().tween_property(attack_button, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
	
	# 2. Volta ao tamanho e cor normais suavemente
	tween.tween_property(attack_button, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(attack_button, "modulate", Color.WHITE, 0.15)
