extends Node
class_name Troop
var commander : Individual
var commander_x : float
var soldiers : Array
var soldiers_count: int
var _murder_queue : Array

func setup(commander_Indi, x):
	commander = commander_Indi
	commander_x = x
func found_new_civilian_flee(indi: Individual):
	if indi.is_commander:
		var new_commander = soldiers \
		.filter(func(s): return s.stubbornness > 0) \
		.reduce(func(a, b): return a if a.stubbornness > b.stubbornness else b)
		if new_commander != null:
			commander = new_commander
			commander.is_commander = true
	_murder_queue.append(indi)
# 
func _run_murder_queue():
	if _murder_queue.is_empty(): return
	var victim = _murder_queue.pop_front()
	if victim != null:
		execute(victim)
	_run_murder_queue()
func execute(indi: Individual):
	pass
