extends Node
@onready var main_scene: MainScene = $".."
@onready var troop_manager: TroopManager = $"../TroopManager"
@onready var cursor: Node2D = $"../Cursor"
@onready var sorry_text_canvas_layer: CanvasLayer = $"../CanvasLayer"
@onready var audio_stream_player: AudioStreamPlayer2D = $"../AudioStreamPlayer2D"

@export var sidemost_buffer := 10.0
@export var gathering_pos_x_offset := 10.0
@export var gathering_pos_y_offset := 60.0
@export var base_activist_strength : int = 1
@export var activist_strength_accum := 0.6
@export var bad_ending_count := 5
@export var good_ending_count := 70
@export var conscription_schedule := [
	{ "commander_num": 10, "soldier_num": 20, "delay": 20.0 },
	{ "commander_num": 5, "soldier_num": 20, "delay": 30.5 },
	{ "commander_num": 10, "soldier_num": 50, "delay": 40.0 },
]
@export var music : AudioStream
var activist_strength
var activist_alliance := []
var conscription_count := 0 : # debugger
	set(value):
		conscription_count = value
		print(value)
var _index := 0
var _running := true
var _crossed_bad_ending_line_count := 0
var _supporters_count := 0
var _init_cursor_cd

signal good_ending_trigger
signal bad_ending_trigger

func _ready():
	await get_parent().ready
	var horizon_y = main_scene.horizon_y
	var middle_left_x = main_scene.side_width
	var middle_right_x = main_scene.side_width + main_scene.middle_width
	Data.horizon_y = horizon_y
	Data.most_y = main_scene.screen_size.y
	Data.screen_width = main_scene.screen_size.x
	var gathering_y = horizon_y + gathering_pos_y_offset
	Data.left_gethering_pot = Vector2(middle_left_x - gathering_pos_x_offset, gathering_y)
	Data.right_gethering_pot = Vector2(middle_right_x + gathering_pos_x_offset, gathering_y)
	Data.left_rect = main_scene.left_rect
	Data.right_rect = main_scene.right_rect
	_init_cursor_cd = cursor.cold_duration
	activist_strength = base_activist_strength
	troop_manager.horizon_y = horizon_y
	troop_manager.leftmost_x = middle_left_x + sidemost_buffer
	troop_manager.rightmost_x = middle_right_x - sidemost_buffer
	_run_conscription()
	
func _stop_conscription(): _running = false
func _run_conscription():
	if !_running: return
	if _index >= conscription_schedule.size(): _index = 0
	var entry = conscription_schedule[_index]
	var c_num = entry["commander_num"]
	var s_num = entry["soldier_num"]
	var delay = entry["delay"]
	troop_manager.conscript(c_num, s_num)
	_index += 1
	#print("START NEW CONSCRIPTION")
	await Toolkit.wait(delay)
	_run_conscription()
	conscription_count += 1
func on_individual_became_real_activist(individual):
	activist_alliance.append(individual)
	activist_strength += activist_strength_accum
	#cursor.mouse_radius += activist_strength
	cursor.cold_duration -= _init_cursor_cd / (good_ending_count * 2)
	print("activist_strength: ", activist_strength)
	_supporters_count += 1
	if _supporters_count >= good_ending_count:
		_on_good_ending()
func on_crossed_bad_ending_line():
	_crossed_bad_ending_line_count += 1
	print(_crossed_bad_ending_line_count)
	if _crossed_bad_ending_line_count >= bad_ending_count:
		_on_bad_ending()
func _on_bad_ending():
	#_stop_conscription()
	emit_signal("bad_ending_trigger")
	print("It's bad ending!")
	
func _on_good_ending():
	_stop_conscription()
	Toolkit.cancel_signal.emit()
	emit_signal("good_ending_trigger")
	print("It's good ending!")
	await Toolkit.wait(4)
	sorry_text_canvas_layer.visible = true
	await Toolkit.wait(13)
	sorry_text_canvas_layer.visible = false
	await Toolkit.wait(5)
	audio_stream_player.stream = music
	audio_stream_player.stream.set_loop(true)
	audio_stream_player.play()
	# capture the screen (inactivate no_to_war_zone texture)
