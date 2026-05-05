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
		
	# Hide it initially
	xrtools_hand.visible = false
	
	# Now, we can make sure to hide/show these mimic hands when we pick/drop XRToolPickables.
	xrt_function_pickup.connect("has_picked_up", _on_picked_up)
	xrt_function_pickup.connect("has_dropped", _on_dropped)

## Hide this hand, show the XRTools hand so those grab points can display with the pose animations.
func _on_picked_up(what: Variant) -> void:
	# Make sure the mesh of the finger tracked hand is copied onto the hand mimic
	_hand_mesh = _find_child(self, "MeshInstance3D")
	xrtools_hand._hand_mesh.mesh = _hand_mesh.mesh
	xrtools_hand.hand_material_override = _hand_mesh.material_override
	
	get_child(0).visible = false
	xrtools_hand.visible = true
	
	if is_instance_valid(rigid_collision_hand):
		if what is RigidBody3D:
			add_collision_exclusion(what)

## Show this hand, hide the XRTools hand.
func _on_dropped() -> void:
	get_child(0).visible = true
	xrtools_hand.visible = false

## In the case that we are using RigidCollisionHand, add collision exclusion to a pickable item.
func add_collision_exclusion(what: RigidBody3D) -> void:
	for physics_body: PhysicsBody3D in rigid_collision_hand.get_collision_exceptions():
		rigid_collision_hand.remove_collision_exception_with(physics_body)
	
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
