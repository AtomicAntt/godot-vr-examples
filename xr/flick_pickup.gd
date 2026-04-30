class_name FlickPickup
extends Node3D

## Not necessarily the XRTools function_pickup, but it must have the "picked_up_object" property/variable.
@export var function_pickup: Node3D

## The pickup action name. Default is "grip".
@export var grip_action: String = "grip"

## The float value that the pickup action (grip) must exceed to register that the player wants to flick pickup something.
@export var grip_threshold: float = 0.7

## The XR controller. Default value is the parent.
@export var xr_controller: XRController3D

## Setting default values as 3. Since XRTools has pickables in layer 3, that's what we'll try to scan.
const DEFAULT_GRAB_MASK := 0b0000_0000_0000_0000_0000_0000_0000_0100

## The collision mask of our ranged grab area. Select the layers which you want to be able to do ranged grabs on.
@export_flags_3d_physics var grab_collision_mask: int = DEFAULT_GRAB_MASK

## Distance threshold to flick pickup an object.
@export var ranged_distance: float = 5.0
## Angle threshold from hand's forward direction to flick pickup an object.
@export_range(0, 90) var ranged_angle: float = 45.0

## Anything in this Area3D will be checked for the flick ranged grab.
var grab_area: Area3D
## The collision shape of the grab_area.
var ranged_collision: CollisionShape3D

## This is the closest object that can currently be flick picked up.
var current_closest_object: Node3D

## List of RigidBody3Ds that are within the grab area.
var grab_range_list: Array[RigidBody3D] = []

var grip_pressed: bool = false 

## Once an object is gripped from afar, we store the initial direction to the object when gripped.
var initial_grip_direction: Vector3

## Required change in angle from the initial grip direction of an object to flick pickup them.
@export_range(0, 30) var flick_angle_threshold: float = 10.0
## Required magnitude of the angular velocity to flick pickup an object.
@export var angular_velocity_threshold: float = 2.0

func _ready() -> void:
	if not is_instance_valid(xr_controller):
		if get_parent() is XRController3D:
			xr_controller = get_parent()
	
	ranged_collision = CollisionShape3D.new()
	ranged_collision.set_name("RangedCollisionShape")
	ranged_collision.shape = CylinderShape3D.new()
	ranged_collision.transform.basis = Basis(Vector3.RIGHT, PI/2)
	
	grab_area = Area3D.new()
	grab_area.name = "FlickGrabArea"
	grab_area.collision_layer = 0
	grab_area.collision_mask = grab_collision_mask
	grab_area.body_entered.connect(_on_grab_area_entered)
	grab_area.body_exited.connect(_on_grab_area_exited)
	grab_area.add_child(ranged_collision)
	function_pickup.add_child(grab_area)
	
	_update_colliders()

func _physics_process(_delta: float) -> void:
	var grip_value: float = xr_controller.get_float(grip_action)
	if (grip_pressed and grip_value < (grip_threshold - 0.1)):
		grip_pressed = false
		on_grip_release()
	elif (!grip_pressed and grip_value > (grip_threshold + 0.1)):
		grip_pressed = true
		on_grip_pressed()
	
	update_closest_object()

func _on_grab_area_entered(body: Node3D) -> void:
	# Compatibility with XRTools
	if not body.has_method("pick_up"):
		return
	
	if body not in grab_range_list:
		grab_range_list.append(body)

func _on_grab_area_exited(body: Node3D) -> void:
	if body in grab_range_list:
		grab_range_list.erase(body)

# Update the colliders geometry
func _update_colliders() -> void:
	if ranged_collision:
		ranged_collision.shape.radius = tan(deg_to_rad(ranged_angle)) * ranged_distance
		ranged_collision.shape.height = ranged_distance
		ranged_collision.transform.origin.z = -ranged_distance * 0.5

## Gets the closest object to the hand's forward direction vector within grab_range_list.
func get_closest_object() -> Node3D:
	var closest_object: Node3D = null
	var closest_dot_product: float = cos(deg_to_rad(ranged_angle))
	var forward_direction: Vector3 = -grab_area.global_transform.basis.z
	for object in grab_range_list:
		# Compatibility with XRTools
		if object.has_method("can_pick_up"):
			if not object.can_pick_up(self):
				continue
		
		var direction_to_object: Vector3 = (object.global_position - global_position).normalized()
		
		# Should be between 0 (90 degrees) and 1 (0 degrees).
		# Degrees being the angle between forward_direction and direction_to_object.
		var dot_product: float = forward_direction.dot(direction_to_object)
		if dot_product > closest_dot_product:
			closest_object = object
			closest_dot_product = dot_product
	return closest_object

func update_closest_object() -> void:
	# Skip if we have already picked up something with this hand.
	if is_instance_valid(function_pickup):
		if "picked_up_object" in function_pickup:
			if function_pickup.picked_up_object:
				return
	
	var new_closest_object: Node3D = get_closest_object()
	
	# Skip if unchanged
	if current_closest_object == new_closest_object:
		return
	
	# Remove highlights on old object
	if is_instance_valid(current_closest_object):
		if current_closest_object.has_method("request_highlight"):
			current_closest_object.request_highlight(self, false)
	
	# Add highlights on new object
	current_closest_object = new_closest_object
	if is_instance_valid(new_closest_object):
		if new_closest_object.has_method("request_highlight"):
			current_closest_object.request_highlight(self, true)
			print("beep beep, new object detected!")

func on_grip_release() -> void:
	if not initial_grip_direction:
		return
	
	var release_grip_direction: Vector3 = -global_transform.basis.z
	var angular_velocity: Vector3 = xr_controller.get_pose().angular_velocity
	
	var dot_product: float = initial_grip_direction.dot(release_grip_direction)
	if dot_product <= cos(deg_to_rad(flick_angle_threshold)) and angular_velocity.length() >= angular_velocity_threshold:
		print("Flicked")
	else:
		print("Attempted flick")

func on_grip_pressed() -> void:
	if not is_instance_valid(current_closest_object):
		return
	initial_grip_direction = global_position.direction_to(current_closest_object.global_position)
	print("Locking in initial grip direction at " + str(initial_grip_direction))
