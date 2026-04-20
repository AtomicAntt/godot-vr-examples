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
	
	# Hide it initially
	xrtools_hand.visible = false
	
	# Now, we can make sure to hide/show these mimic hands when we pick/drop XRToolPickables.
	xrt_function_pickup.connect("has_picked_up", _on_picked_up)
	xrt_function_pickup.connect("has_dropped", _on_dropped)

## Hide this hand, show the XRTools hand so those grab points can display with the pose animations.
func _on_picked_up(_what: Variant) -> void:
	# Make sure the mesh of the finger tracked hand is copied onto the hand mimic
	_hand_mesh = _find_child(self, "MeshInstance3D")
	xrtools_hand._hand_mesh.mesh = _hand_mesh.mesh
	xrtools_hand.hand_material_override = _hand_mesh.material_override
	
	get_child(0).visible = false
	xrtools_hand.visible = true

## Show this hand, hide the XRTools hand.
func _on_dropped() -> void:
	get_child(0).visible = true
	xrtools_hand.visible = false

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
