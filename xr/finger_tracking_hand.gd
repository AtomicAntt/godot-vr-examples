class_name FingerTrackingHand
extends Node3D

var _controller: XRController3D

# Do later: Instantiate XRToolsHand only if XRTools is present, and have this node be offset towards left/right controller
# instead of a child of XROrigin3D to be more in line with XRTools and how you make hands regularly in XR development.
# Yes, it's a band-aid solution to getting finger tracking working with this, but im not a genius lol

@export var hand_mimic: XRToolsHand
@export var function_pickup: XRToolsFunctionPickup

var _hand_mesh: MeshInstance3D

# Get the controller this node has as an ancestor.
func _get_controller() -> XRController3D:
	var parent: Node = get_parent()
	while parent:
		if parent is XRController3D:
			return parent

		parent = parent.get_parent()
	return null

# Process function should offset the hands to align with the XRController3D
func _process(_delta: float) -> void:
	if not _controller:
		visible = false
		return

	var hand_tracker_name: String = ""
	if _controller.tracker == "left_hand":
		hand_tracker_name = "/user/hand_tracker/left"
	elif _controller.tracker == "right_hand":
		hand_tracker_name = "/user/hand_tracker/right"
	else:
		visible = false
		return

	var hand_tracker: XRHandTracker = XRServer.get_tracker(hand_tracker_name)
	if not hand_tracker or not hand_tracker.has_tracking_data:
		visible = false
		return

	var pose: XRPose = hand_tracker.get_pose("default")
	var hand_transform: Transform3D = pose.get_adjusted_transform()

	visible = true
	transform = _controller.global_transform.inverse() * hand_transform


func _ready() -> void:
	_controller = _get_controller()
	
	function_pickup.connect("has_picked_up", on_picked_up)
	function_pickup.connect("has_dropped", on_dropped)
	
	_hand_mesh = _find_child(self, "MeshInstance3D")
	hand_mimic._hand_mesh.mesh = _hand_mesh.mesh

## Hide this hand, show the XRTools hand so those grab points can display with the pose animations.
func on_picked_up(_what: Variant) -> void:
	get_child(0).visible = false
	hand_mimic.visible = true

## Show this hand, hide the XRTools hand.
func on_dropped() -> void:
	get_child(0).visible = true
	hand_mimic.visible = false

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
