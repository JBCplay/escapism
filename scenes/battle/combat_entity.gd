extends Node
class_name CombatEntity

signal exaustao_alterada(is_exausto: bool)
signal entidade_derrotada(is_inimigo: bool)

# --- DEFINIÇÃO DOS ELEMENTOS ---
enum Elemento { FISICO, FOGO, RAIO, BIOLOGICO, AGUA, TERRA, TREVAS }

enum Aflicao {
	MOLHADO,
	LAMACADO,
	EMPOEIRADO,
	QUEIMADURA,
	ELETRO_ATIVA,
	ELETRO_PASSIVA,
	INFECCAO,
	RUINA,
	ATORDOADO,
	DERRUBADO,
	COUNT # Total de entradas alocadas (10)
}

# Vetor com 10 posições estáticas contíguas em memória
var aflicoes: Array[int] = []

func _init() -> void:
	aflicoes.resize(Aflicao.COUNT)
	aflicoes.fill(0)

func has_aflicao(tipo: Aflicao) -> bool:
	return aflicoes[tipo] > 0

# Função unificada para adicionar/remover pilhas (aceita deltas negativos)
func modificar_pilhas_aflicao(tipo: Aflicao, delta: int) -> void:
	# Verificação de segurança de índice do Enum
	if tipo >= 0 and tipo < Aflicao.COUNT:
		aflicoes[tipo] += delta
		# Garante que as pilhas nunca ficam negativas
		aflicoes[tipo] = maxi(0, aflicoes[tipo])

var base_data: EntityData

# Atributos Vitais Primários
var hp_atual: int
var energia_atual: int
var action_value: float = 100.0 # Posição na fila de turnos

# Gerenciamento de Pilhas (Stacks)
var buffs: int = 0
var debuffs: int = 0
var knockback_stacks: int = 0

var is_exausto: bool = false
var is_inimigo: bool = false

func inicializar(data: EntityData, inimigo: bool = false) -> void:
	base_data = data
	hp_atual = base_data.hp_maximo
	energia_atual = base_data.energia_maxima
	is_inimigo = inimigo

func aplicar_dano(dano: int) -> void:
	hp_atual = clampi(hp_atual - dano, 0, base_data.hp_maximo)
	verificar_estado_vital()

func gastar_energia(custo: int) -> void:
	energia_atual = clampi(energia_atual - custo, 0, base_data.energia_maxima)
	verificar_estado_vital()

func verificar_estado_vital() -> void:
	# Derrota instantânea se HP ou Energia zerarem
	if hp_atual <= 0 or energia_atual <= 0:
		entidade_derrotada.emit(is_inimigo)
		return
		
	# Limiar de Exaustão aos 10%
	var hp_percent = float(hp_atual) / base_data.hp_maximo
	var ep_percent = float(energia_atual) / base_data.energia_maxima
	
	var novo_estado_exaustao = (hp_percent <= 0.1) or (ep_percent <= 0.1)
	if is_exausto != novo_estado_exaustao:
		is_exausto = novo_estado_exaustao
		exaustao_alterada.emit(is_exausto)
