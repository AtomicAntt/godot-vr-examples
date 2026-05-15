class_name SpringButton
extends Node3D

## Amount of time it takes to return back to the equilibrium from maximum displacement.
@export var recovery_time: float = 0.1

## Actual button rigidbody
@onready var button_interactable: RigidBody3D = $ButtonInteractable
@onready var equillibrium_marker: Marker3D = $EquillibriumMarker

func _ready() -> void:
	button_interactable.gravity_scale = 0.0

func _physics_process(_delta: float) -> void:
	var equillibrium_global_position = equillibrium_marker.global_position
	apply_force(recovery_time, button_interactable, equillibrium_global_position)

func apply_force(time: float, rigidbody3d: RigidBody3D, target_global_position: Vector3) -> void:
	var half_t2: float = 0.5 * time * time
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(rigidbody3d.get_rid())
	var move_time: Vector3 = target_global_position - rigidbody3d.global_position
	
	var current_velocity: Vector3 = state.linear_velocity * clamp(1.0 - (state.total_linear_damp * time), 0.0, 1.0)
	current_velocity += state.total_gravity * time
	
	var needed_acceleration: Vector3 = (move_time - (current_velocity * time)) / half_t2
	var linear_force: Vector3 = (0.5 / state.inverse_mass) * needed_acceleration
	
	rigidbody3d.apply_central_force(linear_force)
