extends Node
class_name EnemySkills

# Array fixo de habilidades para otimização da IA
var habilidades_fixas: Array[Resource] = []

func inicializar(skills: Array[Resource]) -> void:
	habilidades_fixas = skills

func obter_habilidade_para_ia() -> Resource:
	# Lógica futura da IA para selecionar habilidade baseada em pesos
	if habilidades_fixas.size() > 0:
		return habilidades_fixas.pick_random()
	return null
