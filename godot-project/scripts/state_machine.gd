extends Node

@export var initial_state: State

var current_state: State
var states = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			# Optional: decentralized transition from state itself
			child.transitioned.connect(func(state, new_name): transition(new_name))

	if initial_state:
		current_state = initial_state
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition(new_state_name: String) -> void:
	var new_state = states.get(new_state_name)
	if !new_state or new_state == current_state:
		return

	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
