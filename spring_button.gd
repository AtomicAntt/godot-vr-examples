class_name SpringButton
extends Node3D

## Signal emitted if it was just pressed.
signal pressed

## Whether the button has been pressed or not. Includes when button is held down.
var has_pressed: bool = false

## Amount of time it takes to return back to the equilibrium from maximum displacement.
@export var recovery_time: float = 0.1

## Freezes up when pressed.
@export var disable_on_press: bool = false

## Whether the button springs back to equillibirum and can be pressed again.
@export var disabled: bool = false

## Actual button rigidbody
@onready var button_interactable: RigidBody3D = $ButtonInteractable

## This marks the position which the button ends up after recovering/springing back up.
@onready var equillibrium_marker: Marker3D = $EquillibriumMarker

## This is the global position in which the button is fully pressed.
@onready var base_global_position: Vector3 = $SliderJoint3D.global_position

func _ready() -> void:
	button_interactable.gravity_scale = 0.0
	button_interactable.lock_rotation = true

func _physics_process(_delta: float) -> void:
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
		if has_pressed:
			has_pressed = false

func apply_force(time: float, rigidbody3d: RigidBody3D, target_global_position: Vector3) -> void:
	var half_t2: float = 0.5 * time * time
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(rigidbody3d.get_rid())
	var move_time: Vector3 = target_global_position - rigidbody3d.global_position
	
	var current_velocity: Vector3 = state.linear_velocity * clamp(1.0 - (state.total_linear_damp * time), 0.0, 1.0)
	current_velocity += state.total_gravity * time
	
	var needed_acceleration: Vector3 = (move_time - (current_velocity * time)) / half_t2
	var linear_force: Vector3 = (0.5 / state.inverse_mass) * needed_acceleration
	
	rigidbody3d.apply_central_force(linear_force)
