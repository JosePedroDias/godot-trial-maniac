extends CanvasLayer

@onready var timer_label = $Control/TimerLabel
@onready var finish_label = $Control/FinishLabel
@onready var speed_label = $Control/SpeedLabel

func _ready():
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.time_updated.connect(_on_time_updated)
		gm.state_changed.connect(_on_state_changed)
		gm.speed_updated.connect(_on_speed_updated)
	finish_label.hide()

func _on_speed_updated(speed):
	speed_label.text = str(int(speed)) + " KM/H"

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
	pass
