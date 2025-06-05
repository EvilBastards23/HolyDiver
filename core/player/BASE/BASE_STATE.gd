# STATE.gd
extends Resource
class_name STATE

# Signal emitted to broadcast custom events from this state
signal state_event(event_name: String, data: Dictionary)

# Function references for custom behavior (optional override via callables)
var enter_func: Callable
var exit_func: Callable
var update_func: Callable
var input_func: Callable

# Name identifier for this state (e.g., "Idle", "Attack", etc.)
@export var state_name: String 

# Reference to the state machine that owns this state
var state_machine: STATE_MACHINE

# Called when the state is entered
func enter(owner: Node) -> void:
	if enter_func.is_valid():
		enter_func.call(owner)

# Called when the state is exited
func exit(owner: Node) -> void:
	if exit_func.is_valid():
		exit_func.call(owner)

# Called every frame. Can return the name of the next state to transition to.
func update(owner: Node, delta: float) -> String:
	if update_func.is_valid():
		return update_func.call(owner, delta)
	return ""

# Called when an input event is received. Can return a state name to transition to.
func handle_input(owner: Node, event: InputEvent) -> String:
	if input_func.is_valid():
		return input_func.call(owner, event)
	return ""

# Helper function to request a state transition through the state machine
func transition_to(new_state: String, data: Dictionary = {}) -> void:
	if state_machine:
		state_machine.change_state(new_state, data)

# Helper function to emit a custom event from this state
func broadcast_state(event_name: String, data: Dictionary = {}) -> void:
	state_event.emit(event_name, data)
