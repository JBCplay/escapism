extends Node

enum GameState { MAIN_MENU, EXPLORATION, COMBAT, GAME_OVER }
var current_state: GameState = GameState.MAIN_MENU

# Emite sinal global para que UI e controladores pausem ou ajam
signal state_changed(new_state: GameState)

func change_state(new_state: GameState) -> void:
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(current_state)
