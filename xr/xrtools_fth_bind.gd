class_name XRTFingerTrackingHand
extends FingerTrackingHand
## This class mimics a XRTools Hand to copy their poses.
## Since it is mimicing grab poses, a FunctionPickup must be present as a child of the XRController3D.
## This is a band-aid solution to allow developers to have
## finger tracking hands while still getting to use Godot XR Tools.
## Note: It's not a part of XR Tools, just compatible.

# Setup instructions:
# - Add XRToolsHand scene and XRToolsFunctionPickup scene onto an XRController3D
# - Then, put this node as a child opf an XRController and set the xrtools_hand variable
#   to the XRToolsHand scene in the inspector.

## The hand we are going to mimic as a child of XRController3D
@export var xrtools_hand: XRToolsHand

## This should be present as a child of XRController3D
@export var xrt_function_pickup: XRToolsFunctionPickup

## The controller that is an ancestor to this node
var _xr_controller: XRController3D

## The mesh of the finger tracked hand to be copied onto the hand mimic
var _hand_mesh: MeshInstance3D

# ========= Optional compatibility with RigidCollisionHand ============
## We want to exclude collisions with the item recently picked up.
## Should be a child of XRController3D
@export var rigid_collision_hand: RigidCollisionHand
var exclude_pickable_collision: XRToolsPickable
## If the exclude_pickable_collision leaves this area, we can go ahead and remove collision exclusions.
var exclusion_area: Area3D
var exclusion_shape: CollisionShape3D
## We know XRToolsPickables are in layer 3, so it's 3
const DEFAULT_EXCLUSION_MASK := 0b0000_0000_0000_0000_0000_0000_0000_0100

var _palm_collision_shape : CollisionShape3D
var _digit_collision_shapes : Dictionary

## This should be the hand skeleton of the XRTools mimic. It's used IF you have a rigid_collision_hand.
@export var xrt_hand_skeleton : Skeleton3D

class CopiedCollision extends RefCounted:
	var collision_shape : CollisionShape3D
	var org_transform : Transform3D
var _active_copied_collisions : Array[CopiedCollision]

func _ready() -> void:
	super()
	
	_xr_controller = XRHelpers.get_xr_controller(self)
	
	if not is_instance_valid(xrt_function_pickup):
		xrt_function_pickup = _xr_controller.get_node("FunctionPickup")
	
	if not is_instance_valid(xrtools_hand):
		if _controller.tracker == "left_hand":
			xrtools_hand = _xr_controller.get_node("LeftHand")
		elif _controller.tracker == "right_hand":
			xrtools_hand = _xr_controller.get_node("RightHand")
	
	if not is_instance_valid(rigid_collision_hand):
		rigid_collision_hand = _xr_controller.get_node("RigidCollisionHand")
	
	if is_instance_valid(rigid_collision_hand):
		# First, we add an exclusion shape so we can exclude the rigid_collision_hand from colliding after dropping.
		exclusion_shape = CollisionShape3D.new()
		exclusion_shape.set_name("ExclusionShape")
		exclusion_shape.shape = SphereShape3D.new()
		exclusion_shape.shape.radius = 0.1
		exclusion_shape.debug_color = Color("Blue")
		
		exclusion_area = Area3D.new()
		exclusion_area.set_name("ExclusionArea")
		exclusion_area.collision_layer = 0
		exclusion_area.collision_mask = DEFAULT_EXCLUSION_MASK
		exclusion_area.add_child(exclusion_shape)
		
		add_child(exclusion_area)
		exclusion_area.body_exited.connect(_on_exclusion_body_exit)
		
		# Then, we are getting the XRTools hand hand_skeleton, which will be enabled whenever
		# the hand mimic picks up an object so that rigid body collisions can continue from the rigid_collision_hand.
		if is_instance_valid(xrt_hand_skeleton):
			# Create palm shape
			_palm_collision_shape = CollisionShape3D.new()
			_palm_collision_shape.name = "XrtPalm"
			_palm_collision_shape.shape = \
				preload("res://addons/godot-xr-tools/hands/scenes/collision/hand_palm.shape")
			_palm_collision_shape.transform.origin = Vector3(0.0, -0.05, 0.11)
			_palm_collision_shape.debug_color = Color("Purple")
			get_parent().call_deferred("add_child", _palm_collision_shape, false, Node.INTERNAL_MODE_BACK)
			
			# Initially disable its collision
			_palm_collision_shape.set_deferred("disabled", true)
		
			_on_skeleton_updated()
			xrt_hand_skeleton.skeleton_updated.connect(_on_skeleton_updated)
		else:
			print("Hand skeleton for fth bind not found!")
		
	# Hide it initially
	xrtools_hand.visible = false
	
	# Now, we can make sure to hide/show these mimic hands when we pick/drop XRToolPickables.
	xrt_function_pickup.connect("has_picked_up", _on_picked_up)
	xrt_function_pickup.connect("has_dropped", _on_dropped)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(xrt_function_pickup) or not is_instance_valid(rigid_collision_hand) or not is_instance_valid(xrt_hand_skeleton):
		return
	
	_update_copied_collisions()
	
	#if is_instance_valid(xrt_function_pickup.picked_up_object):
		#_on_skeleton_updated()

## Hide this hand, show the XRTools hand so those grab points can display with the pose animations.
func _on_picked_up(what: Variant) -> void:
	# Make sure the mesh of the finger tracked hand is copied onto the hand mimic
	_hand_mesh = _find_child(self, "MeshInstance3D")
	xrtools_hand._hand_mesh.mesh = _hand_mesh.mesh
	xrtools_hand.hand_material_override = _hand_mesh.material_override
	
	# Hide the finger tracked hand, show our hand mimic
	get_child(0).visible = false
	xrtools_hand.visible = true
	
	if is_instance_valid(rigid_collision_hand):
		if what is RigidBody3D:
			add_collision_exclusion(what)
	
		if is_instance_valid(xrt_hand_skeleton):
			# Disable the rigid collision hand collision shapes because we only want our xrtools
			# hand skeleton collision shapes to be in action then.
			for item: String in rigid_collision_hand._digit_collision_shapes:
				rigid_collision_hand._digit_collision_shapes[item].set_deferred("disabled", true)
			rigid_collision_hand._palm_collision_shape.set_deferred("disabled", true)
			
			# Now we want to enable the xrtools xrtools collision shapes so that stuff collides
			# when we are picking stuff up.
			for item: String in _digit_collision_shapes:
				_digit_collision_shapes[item].set_deferred("disabled", false)
			_palm_collision_shape.set_deferred("disabled", false)
			
			copy_collisions()

## Show this hand, hide the XRTools hand.
func _on_dropped() -> void:
	# Show the finger tracked hand, hide our hand mimic
	get_child(0).visible = true
	xrtools_hand.visible = false
	
	if is_instance_valid(xrt_hand_skeleton):
		# Enable the rigid collision hand collision shapes back again
		for item: String in rigid_collision_hand._digit_collision_shapes:
			rigid_collision_hand._digit_collision_shapes[item].set_deferred("disabled", false)
		rigid_collision_hand._palm_collision_shape.set_deferred("disabled", false)
		
		# Disable the xrtools collision as its now visually hidden after not grabbing stuff.
		for item: String in _digit_collision_shapes:
			_digit_collision_shapes[item].set_deferred("disabled", true)
		_palm_collision_shape.set_deferred("disabled", true)
	
	_remove_copied_collisions()

## In the case that we are using RigidCollisionHand, add collision exclusion to a pickable item.
func add_collision_exclusion(what: RigidBody3D) -> void:
	# Remove any collision exclusions this body has had before
	for physics_body: PhysicsBody3D in rigid_collision_hand.get_collision_exceptions():
		rigid_collision_hand.remove_collision_exception_with(physics_body)
	
	# Add collision exclusions on what
	rigid_collision_hand.add_collision_exception_with(what)
	what.add_collision_exception_with(rigid_collision_hand)
	
	exclude_pickable_collision = what
	
	exclusion_shape.debug_color = Color("Green")

func _on_exclusion_body_exit(body: Node3D) -> void:
	if body == exclude_pickable_collision and not xrt_function_pickup.picked_up_object == body:
		rigid_collision_hand.remove_collision_exception_with(body)
		body.remove_collision_exception_with(rigid_collision_hand)
		exclusion_shape.debug_color = Color("Red")

func _find_child(node: Node, type: String) -> Node:
	# Iterate through all children
	for child in node.get_children():
		# If the child is a match then return it
		if child.is_class(type):
			return child

		# Recurse into child
		var found := _find_child(child, type)
		if found:
			return found

	# No child found matching type
	return null

## =================== This function is from the XRTools Collision Hand ===============================
func _on_skeleton_updated():
	if not xrt_hand_skeleton:
		return

	var bone_count = xrt_hand_skeleton.get_bone_count()
	for i in bone_count:
		var bone_transform : Transform3D = xrt_hand_skeleton.get_bone_global_pose(i)
		var collision_node : CollisionShape3D
		var offset : Transform3D
		offset.origin = Vector3(0.0, 0.015, 0.0) # move to side of joint

		var bone_name = xrt_hand_skeleton.get_bone_name(i)
		if bone_name == "Palm_L":
			offset.origin = Vector3(-0.02, 0.025, 0.0) # move to side of joint
			collision_node = _palm_collision_shape
		elif bone_name == "Palm_R":
			offset.origin = Vector3(0.02, 0.025, 0.0) # move to side of joint
			collision_node = _palm_collision_shape
		elif bone_name.contains("Proximal") or bone_name.contains("Intermediate") or \
			bone_name.contains("Distal"):
			if _digit_collision_shapes.has(bone_name):
				collision_node = _digit_collision_shapes[bone_name]
			else:
				collision_node = CollisionShape3D.new()
				collision_node.name = bone_name
				collision_node.shape = \
					preload("res://addons/godot-xr-tools/hands/scenes/collision/hand_digit.shape")
				#get_parent().add_child(collision_node, false, Node.INTERNAL_MODE_BACK)
				get_parent().call_deferred("add_child", collision_node, false, Node.INTERNAL_MODE_BACK)
				# Initially, we want it disabled.
				collision_node.set_deferred("disabled", true)
				collision_node.debug_color = Color("Purple")
				
				_digit_collision_shapes[bone_name] = collision_node

		if collision_node:
			# TODO it would require a far more complex approach,
			# but being able to check if our collision shapes can move to their new locations
			# would be interesting.
			#collision_node.transform = bone_transform * offset

			
			#collision_node.transform = global_transform.inverse() \
				#* xrt_hand_skeleton.global_transform \
				#* xrt_hand_skeleton.get_bone_global_pose(i) \
				#* offset
				
			var global_bone_transform = xrt_hand_skeleton.global_transform * bone_transform
			collision_node.transform = xrtools_hand.global_transform.inverse() * global_bone_transform * offset

## ====================== These functions are from the XRTools Function Pickup =============================

## This is for when you have a rigid_collision_hand and pick something up.
## In addition to collisions for the mimic xrtools hand skeleton, its also the collision shape of
## the pickable grabbed.
func copy_collisions() -> void:
	if not is_instance_valid(rigid_collision_hand) or not is_instance_valid(xrt_function_pickup):
		return
	
	for child: Node in xrt_function_pickup.picked_up_object.get_children():
		if child is CollisionShape3D and not child.disabled:
			var copied_collision : CopiedCollision = CopiedCollision.new()
			copied_collision.collision_shape = CollisionShape3D.new()
			copied_collision.collision_shape.shape = child.shape
			copied_collision.org_transform = child.transform

			rigid_collision_hand.add_child(copied_collision.collision_shape, false, Node.INTERNAL_MODE_BACK)
			copied_collision.collision_shape.global_transform = xrt_function_pickup.picked_up_object.global_transform * \
				copied_collision.org_transform

			_active_copied_collisions.push_back(copied_collision)

# Adjust positions of our collisions to match actual location of object
func _update_copied_collisions():
	if not is_instance_valid(rigid_collision_hand) or not is_instance_valid(xrt_function_pickup):
		return
	
	for copied_collision : CopiedCollision in _active_copied_collisions:
		if is_instance_valid(copied_collision.collision_shape):
			copied_collision.collision_shape.global_transform = xrt_function_pickup.picked_up_object.global_transform * \
				copied_collision.org_transform

# Remove copied collision shapes
func _remove_copied_collisions():
	for copied_collision : CopiedCollision in _active_copied_collisions:
		if is_instance_valid(copied_collision.collision_shape):
			rigid_collision_hand.remove_child(copied_collision.collision_shape)
			copied_collision.collision_shape.queue_free()

	_active_copied_collisions.clear()
