extends Node3D

enum Strategy { SYNTH, SAMPLE }
@export var strategy: Strategy = Strategy.SYNTH

var rpm_raw: float = 0.0:
	set(val):
		rpm_raw = val
		if _active_engine: _active_engine.set("rpm_raw", val)
var throttle: float = 0.0:
	set(val):
		throttle = val
		if _active_engine: _active_engine.set("throttle", val)
var gear: int = 1:
	set(val):
		gear = val
		if _active_engine: _active_engine.set("gear", val)

var _active_engine: Node = null
var _enabled: bool = true

func _ready():
	_init_strategy()

func _init_strategy():
	if _active_engine:
		_active_engine.queue_free()
	
	match strategy:
		Strategy.SYNTH:
			_active_engine = AudioStreamPlayer3D.new()
			_active_engine.set_script(load("res://scripts/engine_sound_synth.gd"))
		Strategy.SAMPLE:
			_active_engine = Node3D.new()
			_active_engine.set_script(load("res://scripts/engine_sound_sample.gd"))
	
	add_child(_active_engine)
	_active_engine.set("rpm_raw", rpm_raw)
	_active_engine.set("throttle", throttle)
	_active_engine.set("gear", gear)
	if _active_engine.has_method("set_enabled"):
		_active_engine.set_enabled(_enabled)

func set_enabled(enabled: bool):
	_enabled = enabled
	if _active_engine and _active_engine.has_method("set_enabled"):
		_active_engine.set_enabled(enabled)

func switch_strategy(new_strategy: Strategy):
	strategy = new_strategy
	_init_strategy()
