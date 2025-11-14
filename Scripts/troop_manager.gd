extends Node
class_name TroopManager
@onready var people: Node2D = $"../People"
@onready var game_manager: Node = $"../GameManager"
@export var s_individual : PackedScene
@export var min_dis_for_commanders : float
@export var min_dis_for_soldiers : float
@export var max_commanders_spawn_attempts : int
@export var max_soldiers_spawn_attempts : int
@export var max_one_troop_range : float
@export var max_one_troop_size : int # how many rows of soldiers it can have
#@export var max_c_stubbornness : float
#@export var max_s_stubbornness : float
# need to get the value from GM in the beginning
var horizon_y
var leftmost_x
var rightmost_x
var _is_ending := false
# <generate a troop>
# 1. spawn commanders randomly around the line, 
#		with the min_dis_for_commanders
# 2. spawn soldiers around commanders
#		with the min_dis_for_soldiers
#	spawn many times with different count
#    #####
#	#######
#  ##########
#   #######
#    ####
#	  ##
func _ready():
	Toolkit.cancel_signal.connect(_on_end)
func conscript(commander_num, soldier_num):
	var troop_arr = _fill_commanders(commander_num)
	_fill_front_line(soldier_num, troop_arr)
func _fill_commanders(count: int) -> Array:
	var attempts := 0
	var x_arr = [] # the x of pos
	while x_arr.size() < count and attempts < max_commanders_spawn_attempts:
		attempts += 1
		var x = randf_range(leftmost_x, rightmost_x)
		if _is_valid_spawn(x, x_arr, true):
			x_arr.append(x)
	var troop_arr = []
	for x in x_arr:
		var pos = Vector2(x, horizon_y)
		var indi = _spawn_individual(pos)
		var troop = Troop.new()
		troop.setup(indi, x)
		people.add_child(troop)
		indi.setup(true, troop)
		troop.add_child(indi)
		troop_arr.append(troop)
	return troop_arr
func _fill_front_line(total_count: int, troops: Array):
	var distribution = _distribute_soldiers_into_troops(total_count, troops.size())
	if distribution.size() != troops.size():
		push_error("soldier distribution caculation wrong!")
	
	for i in range(troops.size()):
		troops[i].soldiers_count = distribution[i]
	for troop in troops:
		_spawn_troops_async(troop)
func _spawn_troops_async(troop):
	await _spawn_troops(troop)
func _spawn_troops(troop):
	var range = max_one_troop_range
	var rows : int = randi_range(4, 6)
	var distribution = distribute_soldiers_into_rows(troop.soldiers_count, rows)
	for count in distribution:
		_fill_soldiers(count, troop, range)
		var dur = randf_range(2.8, 3.2)
		await  Toolkit.wait(dur)
		if _is_ending == true: break
func _fill_soldiers(count: int, troop: Troop, troop_range: float):
	var c_x = troop.commander_x
	var x_arr = [] # the x of pos
	var attempts := 0
	var left = max(leftmost_x, (c_x - troop_range))
	var right = min(rightmost_x, (c_x + troop_range))
	while x_arr.size() < count and attempts < max_soldiers_spawn_attempts:
		attempts += 1
		var x = randf_range(left, right)
		if _is_valid_spawn(x, x_arr, false):
			x_arr.append(x)
	for x in x_arr:
		var pos = Vector2(x, horizon_y)
		var indi = _spawn_individual(pos)
		indi.setup(false, troop)
		troop.add_child(indi)
		troop.soldiers.append(indi)
func _is_valid_spawn(new_x: float, existing_x_arr: Array, is_commander: bool) -> bool:
	var min_spacing = min_dis_for_commanders if is_commander else min_dis_for_soldiers
	for x in existing_x_arr:
		if abs(new_x - x) < min_spacing:
			return false
	return true
func _spawn_individual(pos: Vector2) -> Individual:
	if not s_individual:
		push_error("no Individual scene assigned.")
		return
	var indi = s_individual.instantiate() as Individual
	indi.position = pos
	indi.connect("became_real_activist", Callable(game_manager, "on_individual_became_real_activist"))
	indi.connect("crossed_bad_ending_line", Callable(game_manager, "on_crossed_bad_ending_line"))
	game_manager.connect("good_ending_trigger", Callable(indi, "on_good_ending"))
	game_manager.connect("bad_ending_trigger", Callable(indi, "on_bad_ending"))
	return indi
func _distribute_soldiers_into_troops(total_count: int, troop_count: int) -> Array:
	var base = total_count / troop_count
	var result = []
	var remaining = total_count
	for i in range(troop_count):
		var variation = randi_range(-1, 1)  # each troop +/- 1 soldier
		var count = clamp(round(base + variation), 0, remaining)
		result.append(count)
		remaining -= count
	return result
	
func distribute_soldiers_into_rows(total_soldiers: int, rows: int) -> Array:
	var base = []
	var mid = rows / 2
	
	# First, give each row a "weight" — how wide it should be visually
	for i in range(rows):
		var distance_from_center = abs(i - mid)
		var weight = 1.0 / (1.0 + distance_from_center)
		base.append(weight)
	
	# Normalize weights to match total_soldiers
	var sum_weights = base.reduce(func(a, b): return a + b)
	var result = []
	var accumulated = 0
	
	for i in range(rows):
		var count = int(round(base[i] / sum_weights * total_soldiers))
		result.append(count)
		accumulated += count
	
	# Fix rounding errors (add/remove soldiers)
	while accumulated < total_soldiers:
		result[mid] += 1
		accumulated += 1
	while accumulated > total_soldiers:
		result[mid] -= 1
		accumulated -= 1
	
	return result
func _on_end(): _is_ending = true
	
