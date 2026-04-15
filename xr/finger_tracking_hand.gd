class_name FingerTrackingHand
extends XRNode3D

# Do later: Instantiate XRToolsHand only if XRTools is present, and have this node be offset towards left/right controller
# instead of a child of XROrigin3D to be more in line with XRTools and how you make hands regularly in XR development.
# Yes, it's a band-aid solution to getting finger tracking working with this, but im not a genius lol

@export var hand_mimic: XRToolsHand
@export var function_pickup: XRToolsFunctionPickup

var _hand_mesh: MeshInstance3D

func _ready() -> void:
	function_pickup.connect("has_picked_up", on_picked_up)
	function_pickup.connect("has_dropped", on_dropped)
	
	_hand_mesh = _find_child(self, "MeshInstance3D")
	hand_mimic._hand_mesh.mesh = _hand_mesh.mesh

## Hide this hand, show the XRTools hand so those grab points can display with the pose animations.
func on_picked_up(_what: Variant) -> void:
	visible = false
	hand_mimic.visible = true

## Show this hand, hide the XRTools hand.
func on_dropped() -> void:
	visible = true
	hand_mimic.visible = false

func _find_child(node : Node, type : String) -> Node:
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
