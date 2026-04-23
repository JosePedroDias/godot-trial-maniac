class_name Turtle
extends RefCounted

## A 3D Turtle API for procedural track generation.

var transform: Transform3D = Transform3D.IDENTITY
var _stack: Array[Transform3D] = []

func _init(initial_transform: Transform3D = Transform3D.IDENTITY) -> void:
	transform = initial_transform

## Sets the absolute position of the turtle.
func set_position(pos: Vector3) -> void:
	transform.origin = pos

## Returns the current position of the turtle.
func get_position() -> Vector3:
	return transform.origin

## Sets the orientation using a Basis or another Transform3D's basis.
func set_orientation(basis: Basis) -> void:
	transform.basis = basis.orthonormalized()

## Returns the current orientation (basis).
func get_orientation() -> Basis:
	return transform.basis

## Moves the turtle forward along its local Z-axis by [param distance].
## Note: In Godot, -Z is usually forward for cameras/assets, 
## but for procedural generation, we'll follow standard turtle logic (local forward).
func move_forward(distance: float) -> void:
	# Assuming local -Z is forward to match Godot conventions, 
	# or +Z depending on how your track blocks are oriented.
	# Standard Godot forward is -Z.
	transform.origin += transform.basis.z * -distance

## Rotates the turtle around its local Y-axis (Yaw).
func turn_left(angle_degrees: float) -> void:
	transform.basis = transform.basis.rotated(transform.basis.y, deg_to_rad(angle_degrees))

## Rotates the turtle around its local X-axis (Pitch).
func turn_up(angle_degrees: float) -> void:
	transform.basis = transform.basis.rotated(transform.basis.x, deg_to_rad(angle_degrees))

## Rotates the turtle around its local Z-axis (Roll).
func roll(angle_degrees: float) -> void:
	transform.basis = transform.basis.rotated(transform.basis.z, deg_to_rad(angle_degrees))

## Saves the current state (transform) onto the stack.
func push_state() -> void:
	_stack.push_back(transform)

## Restores the last saved state from the stack.
func pop_state() -> void:
	if _stack.size() > 0:
		transform = _stack.pop_back()
	else:
		push_error("Turtle stack underflow: No state to pop.")

## Convenience to get the current Transform3D.
func get_transform() -> Transform3D:
	return transform
