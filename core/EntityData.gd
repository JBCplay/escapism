extends Resource
class_name EntityData

@export var nome_entidade: String = "Entidade Desconhecida"
@export var modelo_visual: PackedScene

@export_group("Atributos Vitais")
@export var hp_maximo: int = 100
@export var energia_maxima: int = 100
@export var agilidade_base: float = 10.0
@export var fraquezas: Array[CombatEntity.Elemento] = []
@export var resistencias: Array[CombatEntity.Elemento] = []

@export_group("Status Estruturais")
# A Estatura (Pequeno, Médio, Grande) define a resistência à quebra de postura (Stagger)
@export_enum("Pequeno", "Médio", "Grande") var estatura: int = 0

@export_group("Habilidades e Comportamento")
# Lista de ações que a entidade pode executar em combate
@export var lista_acoes: Array[Resource] = []
