extends RigidBody2D
var wheels = []
var speed = 3200000
var max_speed = 10

@export var crash_impact_threshold: float = 1200.0  # tweak: how hard a landing/impact needs to be to trigger the ragdoll

var biker: Node2D


func _ready():
	wheels = get_tree().get_nodes_in_group("wheel")
	biker = get_tree().get_first_node_in_group("biker")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("right"):
		for wheel in wheels:
			if wheel.angular_velocity < max_speed:
				wheel.apply_torque_impulse(speed * delta * 60)

	if Input.is_action_just_pressed("left"):
		for wheel in wheels:
			if wheel.angular_velocity > -max_speed:
				wheel.apply_torque_impulse(-speed * delta * 60)


func _on_body_entered(_body: Node) -> void:
	if biker and not biker.is_ragdolled and linear_velocity.length() > crash_impact_threshold:
		biker.ragdoll(linear_velocity, angular_velocity)
