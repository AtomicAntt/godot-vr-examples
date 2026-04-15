class_name FingerTrackingHand
extends XRNode3D

@export var hand_mimic: XRToolsHand
@export var function_pickup: XRToolsFunctionPickup

func _ready() -> void:
	function_pickup.connect("has_picked_up", on_picked_up)
	function_pickup.connect("has_dropped", on_dropped)

func on_picked_up(_what: Variant) -> void:
	visible = false
	hand_mimic.visible = true

func on_dropped() -> void:
	visible = true
	hand_mimic.visible = false
