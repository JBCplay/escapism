extends Resource
class_name SkillData

@export var nome_habilidade: String = "Ataque Básico"
@export var custo_energia: int = 10
@export var multiplicador_dano: float = 1.0

# Enumeração das Afinidades Elementais
@export_enum("Física", "Fogo", "Raio", "Biológico", "Água", "Terra", "Trevas") var elemento: int = 0

# Força base para cálculo de repulsão na fila de turnos
@export var forca_knockback: float = 0.0

# Define se a habilidade gera pilhas de Combo (Stagger) para quebra de postura
@export var dano_postura: int = 1
