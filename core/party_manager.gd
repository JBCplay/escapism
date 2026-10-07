extends Node

const maxPartyMembers : int = 4
# Armazena as instâncias de EntityData dos 5 heróis do jogo
var roster_completo: Array[EntityData] = []

# Referências aos 3 ou 4 membros atualmente escalados para combate
var equipe_ativa: Array[EntityData] = []

var inventario_global: Dictionary = {}

func definir_equipe_ativa(indices: Array[int]) -> void:
	equipe_ativa.clear()
	for i in indices:
		# Limita a escalação ao máximo de 4 membros
		if i < roster_completo.size() and equipe_ativa.size() < maxPartyMembers:
			equipe_ativa.append(roster_completo[i])
