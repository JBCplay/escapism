extends Node
class_name HeroLoadout

# Limita a lista de 3 a 9 slots
var slots_habilidades: Array[Resource] = []

func configurar_loadout(habilidades: Array[Resource]) -> void:
	slots_habilidades.clear()
	for i in range(mini(habilidades.size(), 9)):
		slots_habilidades.append(habilidades[i])
		
func obter_habilidades() -> Array[Resource]:
	return slots_habilidades
