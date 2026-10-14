extends GPUParticles3D

func _ready():
	# Força a partícula a emitir assim que aparecer na tela
	emitting = true
	
	# Espera o tempo exato do Lifetime acabar
	await finished
	
	# Apaga o nó da memória
	queue_free()
