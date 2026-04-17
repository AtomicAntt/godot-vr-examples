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
	linear_damp = 50
	angular_damp = 50
	
	add_skeleton_collisions()
	hand_skeleton.skeleton_updated.connect(add_skeleton_collisions)

func _physics_process(_delta: float) -> void:
	_move_hand_rigidbody_to_contr(self, xr_controller)

func _move_hand_rigidbody_to_contr(hand_rigidbody: RigidBody3D, hand_contr: XRController3D) -> void:
	# 1 force hand rigidbody to hand contr
	var move_delta: Vector3 = hand_contr.global_position - hand_rigidbody.global_position
	
	var coef_force: float = 300.0
	hand_rigidbody.apply_central_force(move_delta * coef_force)
	
	# 2 torque hand rigidbody to hand contr
	var quat_hand_rigidbody: Quaternion = hand_rigidbody.global_transform.basis.get_rotation_quaternion()
	var quat_hand_contr: Quaternion = hand_contr.global_transform.basis.get_rotation_quaternion()
	var quat_delta: Quaternion = quat_hand_contr * (quat_hand_rigidbody.inverse())
	var rotation_delta: Vector3 = Vector3(quat_delta.x, quat_delta.y, quat_delta.z) * quat_delta.w
	
	var coef_torque: float = 6.0
	hand_rigidbody.apply_torque(rotation_delta * coef_torque)

func add_skeleton_collisions() -> void:
	if hand_skeleton:
		var bone_count = hand_skeleton.get_bone_count()
		for i in bone_count:
			var bone_transform : Transform3D = hand_skeleton.get_bone_global_pose(i)
			var collision_node : CollisionShape3D
			var offset : Transform3D
			offset.origin = Vector3(0.0, 0.015, 0.0) # move to side of object

			var bone_name = hand_skeleton.get_bone_name(i)
			if bone_name == "LeftHand" or bone_name == "RightHand":
				offset.origin = Vector3(0.0, 0.025, 0.0) # move to side of object
				collision_node = _palm_collision_shape
			elif bone_name.contains("Proximal") or bone_name.contains("Intermediate") or \
				bone_name.contains("Distal"):
				if _digit_collision_shapes.has(bone_name):
					collision_node = _digit_collision_shapes[bone_name]
				else:
					collision_node = CollisionShape3D.new()
					collision_node.name = bone_name + "Col"
					collision_node.shape = \
						preload("res://xr/xrt2_hand_palm.shape")
					add_child(collision_node, false, Node.INTERNAL_MODE_BACK)
					_digit_collision_shapes[bone_name] = collision_node

			if collision_node:
				# TODO it would require a far more complex approach,
				# but being able to check if our collision shapes
				# can move to their new locations would be interesting.

				# For now just copy our transform to our collision shape
				#collision_node.transform = bone_transform * offset
				var global_bone_transform = hand_skeleton.global_transform * bone_transform
				collision_node.transform = global_transform.inverse() * global_bone_transform * offset
