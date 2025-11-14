extends Node
class_name Troop
var commander : Individual
var commander_x : float
var soldiers : Array
var soldiers_count: int
var _murder_queue : Array
var _murdering := false :
	set(value):
		if value == _murdering: return
		_murdering = value
		if _murdering == true: await _run_murder_queue()
var _commander_mutex = Mutex.new()
func _ready():
	Toolkit.cancel_signal.connect(_on_good_ending)
func setup(commander_Indi, x):
	commander = commander_Indi
	commander_x = x
func found_new_civilian_flee(indi: Individual):
	_murder_queue.append(indi)
	if indi.is_commander:
		_commander_mutex.lock()	
		if indi.is_commander:
			indi.is_commander = false
			var still_soldiers = soldiers.filter(func(s): return s.stubbornness > 0)
			var new_commander = null
			if still_soldiers.is_empty():
				commander = null
				_murder_queue.clear()
				print("no soldier anymore")
				return
			else:
				new_commander = still_soldiers.reduce(func(a, b): return a if a.stubbornness > b.stubbornness else b)
			if new_commander != null:
				commander = new_commander
				commander.is_commander = true
				commander.stubbornness += 20
		_commander_mutex.unlock()
	_murdering = true
func _run_murder_queue():
	while not _murder_queue.is_empty():
		var victim = _murder_queue.pop_front()
		if is_instance_valid(victim):
			await execute(victim)
	await Toolkit.wait(0.1)
	_murdering = false
func execute(indi: Individual):
	if is_instance_valid(commander) and commander != null and commander.is_commander:
		await commander.murder(indi)
func remove_dead(indi: Individual):
	soldiers.erase(indi)
func _on_good_ending():
	_murder_queue.clear()
