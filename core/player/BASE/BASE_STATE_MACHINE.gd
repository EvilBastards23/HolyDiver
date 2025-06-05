# STATE_MACHINE.gd
extends Node
class_name STATE_MACHINE

# Signals to notify when the state changes or an event is broadcasted by a state
signal state_changed(from_state: String, to_state: String, data: Dictionary)
signal state_event_broadcast(event_name: String, data: Dictionary)

# The current active state
var current_state: STATE

# A dictionary holding all possible states by their names
var states: Dictionary = {}

# The node that owns this state machine (usually the character or AI)
var owner_node: Node

func _ready() -> void:
	# Set the owner node to the parent of this state machine
	owner_node = get_parent()

# Add a new state to the state machine
func add_state(state: STATE) -> void:
	states[state.state_name] = state              # Store the state by its name
	state.state_machine = self                   # Let the state know who its state machine is
	state.state_event.connect(_on_state_event)   # Connect state event to this state machine's handler

# Change from the current state to a new state
func change_state(new_state_name: String, data: Dictionary = {}) -> void:
	var new_state = states.get(new_state_name)   # Get the new state by name
	if not new_state:
		print("Warning: State '", new_state_name, "' not found!")
		return                                   # If it doesn't exist, do nothing
	
	var old_state = ""
	if current_state:
		old_state = current_state.state_name     # Save old state's name for signal
		current_state.exit(owner_node)           # Exit the current state
	
	current_state = new_state                     # Set the new state
	current_state.enter(owner_node)               # Enter the new state
	
	# Emit signal that the state has changed
	state_changed.emit(old_state, new_state_name, data)

# Call the current state's update logic and handle state transitions
func update(delta: float) -> void:
	if current_state:
		var next_state = current_state.update(owner_node, delta)
		if next_state != "":
			change_state(next_state)

# Pass input events to the current state and handle potential transitions
func handle_input(event: InputEvent) -> void:
	if current_state:
		var next_state = current_state.handle_input(owner_node, event)
		if next_state != "":
			change_state(next_state)

# Handle events sent from states and re-broadcast them
func _on_state_event(event_name: String, data: Dictionary) -> void:
	state_event_broadcast.emit(event_name, data)

# Optional: Get current state name
func get_current_state_name() -> String:
	if current_state:
		return current_state.state_name
	return ""

# Optional: Check if a specific state is active
func is_state(state_name: String) -> bool:
	if current_state:
		return current_state.state_name == state_name
	return false
