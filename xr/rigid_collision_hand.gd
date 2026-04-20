class_name RigidCollisionHand
extends RigidBody3D

@export var hand_skeleton: Skeleton3D
@export var xr_controller: XRController3D

var _palm_collision_shape: CollisionShape3D
var _digit_collision_shapes: Dictionary[String, CollisionShape3D]

func _ready() -> void:
	_palm_collision_shape = CollisionShape3D.new()
	_palm_collision_shape.name = "PalmCol"
	_palm_collision_shape.shape = preload("res://xr/xrt2_hand_palm.shape")
	# This probably needs to be set based on left or right hand
	_palm_collision_shape.rotation_degrees = Vector3(0.0, 90, 90)
	add_child(_palm_collision_shape, false, Node.INTERNAL_MODE_BACK)
	
	top_level = true
	inertia = Vector3(0.01, 0.01, 0.01)
	continuous_cd = true
	process_physics_priority = -90
	
	add_skeleton_collisions()
	hand_skeleton.skeleton_updated.connect(add_skeleton_collisions)

func _physics_process(delta: float) -> void:
	apply_force_to_hand(delta, self, xr_controller.global_transform.origin)
	apply_torque_to_hand(delta, self, xr_controller.global_basis)

func apply_force_to_hand(delta: float, hand_rigidbody: RigidBody3D, controller_global_position: Vector3) -> void:
	var half_t2: float = 0.5 * delta * delta
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(hand_rigidbody.get_rid())
	var move_delta: Vector3 = controller_global_position - hand_rigidbody.global_position
	
	var current_velocity: Vector3 = state.linear_velocity * clamp(1.0 - (state.total_linear_damp * delta), 0.0, 1.0)
	current_velocity += state.total_gravity * delta
	
	var needed_acceleration: Vector3 = (move_delta - (current_velocity * delta)) / half_t2
	var linear_force: Vector3 = (0.5 / state.inverse_mass) * needed_acceleration
	
	hand_rigidbody.apply_central_force(linear_force)

func apply_torque_to_hand(delta: float, hand_rigidbody: RigidBody3D, controller_global_orientation: Basis) -> void:
	var half_t2: float = 0.5 * delta * delta
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(hand_rigidbody.get_rid())
	var moment_of_inertia: Vector3 = Vector3(1.0, 1.0, 1.0) / state.inverse_inertia
	
	var delta_axis_angle: Vector3 = rotation_to_axis_angle(hand_rigidbody.global_basis, controller_global_orientation)
	var velocity: Vector3 = -hand_rigidbody.angular_velocity
	
	var needed_angular_acceleration: Vector3 = (delta_axis_angle + (velocity * delta)) / half_t2
	var torque: Vector3 = moment_of_inertia * needed_angular_acceleration * 0.5
	
	hand_rigidbody.apply_torque(torque)
	

func add_skeleton_collisions() -> void:
	if hand_skeleton:
		var bone_count = hand_skeleton.get_bone_count()
		for i in bone_count:
			var bone_transform : Transform3D = hand_skeleton.get_bone_global_pose(i)
			var collision_node : CollisionShape3D
			var offset : Transform3D
			offset.origin = Vector3(0.0, 0.015, 0.0) # move to side of object

			var bone_name = hand_skeleton.get_bone_name(i)
			if bone_name == "RightHand":
				offset.basis = Basis.from_euler(Vector3(0, deg_to_rad(0), deg_to_rad(25)))
				#offset.origin = Vector3(0.0, 0.025, 0.0) # move to side of object
				collision_node = _palm_collision_shape
			elif bone_name == "LeftHand":
				offset.basis = Basis.from_euler(Vector3(0, deg_to_rad(0), deg_to_rad(-25)))
				#offset.origin = Vector3(0.0, 0.025, 0.0) # move to side of object
				collision_node = _palm_collision_shape
			elif bone_name.contains("Proximal") or bone_name.contains("Intermediate") or \
				bone_name.contains("Distal"):
				if _digit_collision_shapes.has(bone_name):
					collision_node = _digit_collision_shapes[bone_name]
				else:
					collision_node = CollisionShape3D.new()
					collision_node.name = bone_name + "Col"
					collision_node.shape = \
						preload("res://xr/xrt2_hand_digit.shape")
					add_child(collision_node, false, Node.INTERNAL_MODE_BACK)
					_digit_collision_shapes[bone_name] = collision_node

			if collision_node:
				# TODO it would require a far more complex approach,
				# but being able to check if our collision shapes
				# can move to their new locations would be interesting.

				# For now just copy our transform to our collision shape
				#collision_node.transform = bone_transform * offset
				
				# Also account for offset in positioning hands using XRHandModifier3D
				var global_bone_transform = hand_skeleton.global_transform * bone_transform
				collision_node.transform = global_transform.inverse() * global_bone_transform * offset

## Calculate the axis-angle rotation between two orientations.
func rotation_to_axis_angle(start_orientation : Basis, end_orientation : Basis) -> Vector3:
	var delta_basis: Basis = end_orientation * start_orientation.inverse()
	var delta_quad: Quaternion = delta_basis.get_rotation_quaternion()
	var delta_axis: Vector3 = delta_quad.get_axis().normalized()
	var delta_angle: float = delta_quad.get_angle()

	return delta_axis * delta_angle
