@tool
class_name SpringButton
extends Node3D
## This is a physics based button which is activated with pressure.
## Instructions: If you need to adjust the button distance, please edit button_distance inside the inspector.
## You may move the ButtonBase or remove it if needed.

## Emitted if this button was just pressed.
signal pressed

## Emitted if this button was just released.
signal released

## Whether the button springs back to equillibirum and can be pressed again.
@export var disabled: bool = false

## Whether the button has been pressed or not. Includes when button is held down.
var has_pressed: bool = false

## Disables when pressed.
@export var disable_on_press: bool = false

## How far this button can be pressed.
## Setting this will automatically adjust child nodes.
@export var button_distance: float = 0.03: set = adjust_button

## Amount of time it takes to return back to the equilibrium from maximum displacement.
@export var recovery_time: float = 0.1

## Actual button rigidbody
@onready var button_interactable: RigidBody3D = $ButtonInteractable

@onready var slider_joint: SliderJoint3D = $SliderJoint3D

## This marks the position which the button ends up after recovering/springing back up.
@onready var equillibrium_marker: Marker3D = $EquillibriumMarker

## This is the global position in which the button is fully pressed.
@onready var base_global_position: Vector3 = global_position

func _ready() -> void:
	if Engine.is_editor_hint():
		adjust_button(button_distance)
		return
	
	button_interactable.gravity_scale = 0.0
	button_interactable.lock_rotation = true

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	var equillibrium_global_position = equillibrium_marker.global_position
	apply_force(recovery_time, button_interactable, equillibrium_global_position)
	
	if button_interactable.global_position.distance_squared_to(base_global_position) <= 0.00001 and not has_pressed:
		has_pressed = true
		if disable_on_press:
			button_interactable.freeze = true
		emit_signal("pressed")
	
	# This is to ensure that it can be unpressed when it's only halfway towards the equilibrium point.
	var half_way_point: Vector3 = (equillibrium_marker.global_position + base_global_position) / 2
	
	if button_interactable.global_position.distance_squared_to(half_way_point) <= 0.00001 and has_pressed:
		has_pressed = false
		emit_signal("released")

func adjust_button(new_button_distance: float = button_distance) -> void:
	if Engine.is_editor_hint():
		button_distance = new_button_distance
		# First we set the slider joint position to ensure it's the same as this node.
		slider_joint.global_position = global_position
		# Then, we set the lower linear limit to be the button_distance.
		slider_joint.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, -abs(new_button_distance))
		equillibrium_marker.global_position = global_position + (global_basis.y * abs(new_button_distance))
		button_interactable.global_position = equillibrium_marker.global_position

func apply_force(time: float, rigidbody3d: RigidBody3D, target_global_position: Vector3) -> void:
	var half_t2: float = 0.5 * time * time
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(rigidbody3d.get_rid())
	var move_time: Vector3 = target_global_position - rigidbody3d.global_position
	
	var current_velocity: Vector3 = state.linear_velocity * clamp(1.0 - (state.total_linear_damp * time), 0.0, 1.0)
	current_velocity += state.total_gravity * time
	
	var needed_acceleration: Vector3 = (move_time - (current_velocity * time)) / half_t2
	var linear_force: Vector3 = (0.5 / state.inverse_mass) * needed_acceleration
	
	rigidbody3d.apply_central_force(linear_force)
