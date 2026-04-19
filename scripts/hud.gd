extends Control

@onready var timer_label = $TimerLabel
@onready var finish_label = $FinishLabel

func _ready():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.time_updated.connect(_on_time_updated)
		gm.state_changed.connect(_on_state_changed)
	finish_label.hide()

func _on_time_updated(time):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		timer_label.text = gm.format_time(time)

func _on_state_changed(state):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if state == gm.RaceState.FINISHED:
			finish_label.text = "Finished!\nTime: " + gm.format_time(gm.race_time) + "\nBest: " + gm.format_time(gm.best_time)
			finish_label.show()
		elif state == gm.RaceState.PRE_START:
			finish_label.hide()
			timer_label.text = "00:00.000"

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.reset_race()
