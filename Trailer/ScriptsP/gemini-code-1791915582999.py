code = """extends CanvasLayer

@onready var attack_button = $AttackButton

func _ready():
\tif attack_button:
\t\tattack_button.hide()
\t\t
\t\t# --- ESTILIZAÇÃO DO BOTÃO VIA CÓDIGO ---
\t\t# Remove a borda/fundo cinza padrão e cria um botão vermelho vivo
\t\tvar style_normal = StyleBoxFlat.new()
\t\tstyle_normal.bg_color = Color("d62828") # Vermelho vibrante
\t\tstyle_normal.corner_radius_top_left = 8
\t\tstyle_normal.corner_radius_top_right = 8
\t\tstyle_normal.corner_radius_bottom_left = 8
\t\tstyle_normal.corner_radius_bottom_right = 8
\t\t# Uma leve sombra pra dar destaque
\t\tstyle_normal.shadow_color = Color(0, 0, 0, 0.5)
\t\tstyle_normal.shadow_size = 4
\t\tstyle_normal.shadow_offset = Vector2(0, 4)
\t\t
\t\tattack_button.add_theme_stylebox_override("normal", style_normal)
\t\tattack_button.add_theme_stylebox_override("hover", style_normal)
\t\tattack_button.add_theme_stylebox_override("pressed", style_normal)
\t\tattack_button.add_theme_stylebox_override("focus", style_normal)
\t\t
\t\t# Deixa o texto em negrito, branco e maior
\t\tattack_button.add_theme_color_override("font_color", Color.WHITE)
\t\tattack_button.add_theme_font_size_override("font_size", 24)
\t\t
\t\t# Posiciona no canto inferior esquerdo com um bom espaçamento
\t\t# (Considerando uma resolução base de 1920x1080)
\t\tattack_button.custom_minimum_size = Vector2(200, 60)
\t\tattack_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
\t\tattack_button.position = Vector2(50, -110) # 50px da esquerda, 110px do fundo
\t\t
\t\tattack_button.pivot_offset = attack_button.size / 2

func setup_ui(is_hero_attacking: bool):
\tif not attack_button: return
\t
\tif is_hero_attacking:
\t\tattack_button.show()
\telse:
\t\tattack_button.hide()

func animate_press():
\tif not attack_button or not attack_button.visible:
\t\treturn

\tvar tween = create_tween()
\t
\ttween.tween_property(attack_button, "scale", Vector2(1.15, 1.15), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
\ttween.parallel().tween_property(attack_button, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
\t
\ttween.tween_property(attack_button, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
\ttween.parallel().tween_property(attack_button, "modulate", Color.WHITE, 0.15)
"""
with open("fake_ui_3.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("fake_ui_3.gd created successfully with tag: [file-tag: fake_ui_3-xxxxxxxxxx]")