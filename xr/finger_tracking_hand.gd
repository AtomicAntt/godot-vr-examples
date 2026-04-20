class_name FingerTrackingHand
extends Node3D

var _controller: XRController3D

## Get the controller this node has as an ancestor.
func _get_controller() -> XRController3D:
	var parent: Node = get_parent()
	while parent:
		if parent is XRController3D:
			return parent

		parent = parent.get_parent()
	return null

func _ready() -> void:
	_controller = _get_controller()
	
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
