extends Node

var car: RigidBody3D

func setup(_car: RigidBody3D):
	car = _car

func apply_physics(delta: float):
	pass

func update_wheels(delta: float, steering_input: float, wheel_rot: float):
	pass
