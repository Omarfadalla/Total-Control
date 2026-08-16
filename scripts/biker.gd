extends Node2D

## Biker ragdoll rig.
##
## Every limb is a RigidBody2D with freeze_mode = KINEMATIC and freeze = true
## (see biker.tscn), so physics never touches them — the AnimationPlayer has
## full, direct authority over each limb's position/rotation. That's what
## lets idle and crash poses be fully authored instead of physics-simulated,
## and it's why rotation deltas in every animation stay modest: each sprite
## sits thousands of pixels from its own node's pivot, so even a small
## rotation sweeps the sprite through a big arc. Position carries the motion;
## rotation just adds a little natural tilt on top.

signal crashed(animation_name: String)
signal crash_finished

@onready var anim_player: AnimationPlayer = $AnimationPlayer

const CRASH_ANIMATIONS := ["crash_forward", "crash_backward", "crash_spin"]
const IDLE_VARIATIONS := ["idle_look_around", "idle_weight_shift", "idle_rev_engine"]

## How long the whole-rig launch/fall/land arc takes and how high it peaks.
## Kept close to the crash animation's length (0.72s) so the limbs finish
## scattering right around the moment the rig lands.
const ARC_DURATION := 0.72
const ARC_HEIGHT := 160.0

var _idle_timer: Timer
var _is_crashed := false
var _rig_rest_position: Vector2


func _ready() -> void:
	_rig_rest_position = position
	anim_player.animation_finished.connect(_on_animation_finished)
	_start_idle_cycle()
	anim_player.play("idle_breathing")


# ---------------------------------------------------------------------------
# Idle behaviour: idle_breathing loops forever as the default resting pose.
# Every few seconds a one-shot variation (look around / shift weight / rev
# the engine) plays on top, then hands control back to idle_breathing —
# small, randomized touches so the biker doesn't look frozen or robotic
# while just sitting there.
# ---------------------------------------------------------------------------

func _start_idle_cycle() -> void:
	_idle_timer = Timer.new()
	_idle_timer.one_shot = true
	add_child(_idle_timer)
	_idle_timer.timeout.connect(_play_random_idle_variation)
	_queue_next_idle_variation()


func _queue_next_idle_variation() -> void:
	# Randomized wait so the fidgeting never falls into a predictable rhythm.
	_idle_timer.start(randf_range(3.0, 6.5))


func _play_random_idle_variation() -> void:
	if _is_crashed:
		return
	var variation: String = IDLE_VARIATIONS[randi() % IDLE_VARIATIONS.size()]
	anim_player.play(variation)


func _on_animation_finished(anim_name: String) -> void:
	if anim_name in IDLE_VARIATIONS:
		anim_player.play("idle_breathing")
		_queue_next_idle_variation()
	elif anim_name in CRASH_ANIMATIONS:
		crash_finished.emit()


# ---------------------------------------------------------------------------
# Crash behaviour: pick (or accept) one of the three limb-scatter animations
# and, in parallel, tween the whole rig through a launch / fall / land arc
# so the biker actually goes airborne instead of scattering limbs in place.
# ---------------------------------------------------------------------------

## Trigger a crash. Pass a specific animation name ("crash_forward",
## "crash_backward", "crash_spin") to force one, or leave blank to pick
## randomly.
func crash(kind: String = "") -> void:
	if _is_crashed:
		return
	_is_crashed = true
	_idle_timer.stop()

	var animation_name: String = kind if kind in CRASH_ANIMATIONS else CRASH_ANIMATIONS[randi() % CRASH_ANIMATIONS.size()]
	anim_player.play(animation_name)
	crashed.emit(animation_name)
	_play_flight_arc(animation_name)


func _play_flight_arc(animation_name: String) -> void:
	# Horizontal drift depends on crash direction; a spin barely drifts at
	# all — it mostly rockets straight up and tumbles back down.
	var horizontal_drift := 0.0
	match animation_name:
		"crash_forward":
			horizontal_drift = 260.0
		"crash_backward":
			horizontal_drift = -220.0
		"crash_spin":
			horizontal_drift = randf_range(-60.0, 60.0)

	var launch_target := _rig_rest_position + Vector2(horizontal_drift * 0.5, -ARC_HEIGHT)
	var land_target := _rig_rest_position + Vector2(horizontal_drift, 0.0)

	var tween := create_tween()
	# Launch: fast ease-out rise, like getting thrown clear of the bike.
	tween.tween_property(self, "position", launch_target, ARC_DURATION * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fall: accelerating back down under gravity.
	tween.tween_property(self, "position", land_target, ARC_DURATION * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Land: a tiny settle bounce so the impact actually reads.
	tween.tween_property(self, "position", land_target + Vector2(0, -14), ARC_DURATION * 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", land_target, ARC_DURATION * 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Call once the crash has been shown for as long as you want (e.g. after
## crash_finished + a short pause) to put the biker back on its feet.
func reset_pose() -> void:
	_is_crashed = false
	position = _rig_rest_position
	anim_player.play("idle_breathing")
	_queue_next_idle_variation()
