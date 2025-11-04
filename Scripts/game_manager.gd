extends Node
@onready var main_scene: MainScene = $".."
@onready var troop_manager: TroopManager = $"../TroopManager"
@onready var cursor: Node2D = $"../Cursor"

@export var sidemost_buffer := 10.0
@export var gathering_pos_x_offset := 10.0
@export var gathering_pos_y_offset := 30.0
@export var base_activist_strength : int = 1

@export var conscription_schedule := [
	{ "commander_num": 10, "soldier_num": 20, "delay": 20.0 },
	{ "commander_num": 5, "soldier_num": 20, "delay": 30.5 },
	{ "commander_num": 10, "soldier_num": 50, "delay": 40.0 },
]
var activist_strength
var activist_alliance := []
var _index := 0
var _running := true
func _ready():
	await get_parent().ready
	var horizon_y = main_scene.horizon_y
	var middle_left_x = main_scene.side_width
	var middle_right_x = main_scene.side_width + main_scene.middle_width
	Data.horizon_y = horizon_y
	Data.most_y = main_scene.screen_size.y
	var gathering_y = horizon_y + gathering_pos_y_offset
	Data.left_gethering_pot = Vector2(middle_left_x - gathering_pos_x_offset, gathering_y)
	Data.right_gethering_pot = Vector2(middle_right_x + gathering_pos_x_offset, gathering_y)
	Data.left_rect = main_scene.left_rect
	Data.right_rect = main_scene.right_rect
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
	print("START NEW CONSCRIPTION")
	await get_tree().create_timer(delay).timeout
	_run_conscription()
	
func on_individual_became_real_activist(individual):
	activist_alliance.append(individual)
	activist_strength += 1
	cursor.mouse_radius += activist_strength
	cursor.cold_duration -= 0.1
	print("activist_strength: ", activist_strength)
