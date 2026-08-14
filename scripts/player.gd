extends RigidBody2D

var wheels = []
var speed = 3200000
var max_speed = 10 

func _ready():
	wheels = get_tree().get_nodes_in_group("wheel")

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("right"):
		for wheel in wheels:
			if wheel.angular_velocity < max_speed:
				wheel.apply_torque_impulse(speed * delta * 60) 
	
	if Input.is_action_just_pressed("left"):
		for wheel in wheels:
			if wheel.angular_velocity > -max_speed:
				wheel.apply_torque_impulse(-speed * delta * 60)
