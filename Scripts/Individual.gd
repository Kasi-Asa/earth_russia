extends CharacterBody2D
class_name Individual
@onready var anim_sprite0: AnimatedSprite2D = $Sprite
var _horizon_y
var _most_y
var _screen_width
var _speed : float
var _dir := Vector2.DOWN
var _gathering_pos : Vector2
var _safe_zone_rect : Rect2
var _wandering_time
var _has_apologized := false
var _has_gun := true
var _locating_left : bool
var _troop : Troop
var ca_type : int # 0, 1 or 2
var is_commander : bool
var stubbornness : float :
	set(value):
		if value != stubbornness:
			stubbornness = value
			_on_stubbness_changed()
@export var base_speed: float = 3
@export var flee_speed: float = 10
@export var wander_speed: float = 30
@export var retreat_speed: float = 100
@export var min_scale := 1.0
@export var max_scale := 10.0
@export var min_c_stub = 4
@export var max_c_stub = 20
@export var min_s_stub = 2
@export var max_s_stub = 10
@export_range(1, 10) var click_strength_multiplier := 2
@export var freeze_duration := 3.0
@export var base_wandering_time := 15.0
@export var randf_wandering_time := 2.0
@export var bad_ending_line_y_offset := 100
@export var gunshot_sfx : Array[AudioStream]
enum Identity {SOLDIER, CIVILIAN, ACTIVIST}
enum State {EMERGE, MARCH, FREEZE, SHOOT, APOLOGIZE, FLEE, WANDER, SUPPORT, DIE}
var identity := Identity.SOLDIER :
	set(value):
		if value != identity:
			identity = value
			_on_identity_changed(value)
var state := State.EMERGE
var anim_sprite : AnimatedSprite2D
signal became_real_activist(individual)
signal crossed_bad_ending_line()
func _ready():
	_horizon_y = Data.horizon_y
	_most_y = Data.most_y
	_screen_width = Data.screen_width
	_speed = base_speed
	_wandering_time = base_wandering_time + randf_range(-randf_wandering_time, randf_wandering_time)
	anim_sprite = anim_sprite0
	ca_type = randi_range(0, 2)
	_set_both_process(false)
	_set_state(State.EMERGE)
func setup(commander_bool: bool, troop: Troop):
	is_commander = commander_bool
	_troop = troop
	stubbornness = randi_range(min_c_stub, max_c_stub) if is_commander else randi_range(min_s_stub, max_s_stub)
	#print(is_commander, " ", stubbornness)
func react_to_click(strength: int):
	_reduce_stubbornness(strength * click_strength_multiplier)
	if identity == Identity.SOLDIER and state != State.EMERGE:
		_shock_soldier()
func enter_no_to_war_zone(strength: int):
	_reduce_stubbornness(strength)
	#print("enter no to war zone")
func _reduce_stubbornness(strength):
	stubbornness -= strength
	#print(stubbornness)
func _physics_process(delta: float):
	match state:
		State.MARCH:
			_march()
		State.FLEE:
			_flee()
		State.WANDER:
			_wander(delta)
		State.APOLOGIZE:
			# wait for the preformance
			_retreat()
			
func _process(_delta: float):
	_change_size()
	z_index = int(global_position.y)
func _march():
	velocity = _dir * _speed
	move_and_slide()
	_check_bad_ending_line()
func _flee():
	if _has_gun: return
	var dir = (_gathering_pos - position).normalized()
	velocity = dir * _speed
	move_and_slide()
func _wander(delta: float):
	# get a random location and move to there until timeout, then set_state() -> support
	if _wandering_time > 0:
		if position.distance_squared_to(_gathering_pos) > 2.0:
			var dir = position.direction_to(_gathering_pos)
			velocity = dir * _speed
			move_and_slide()
		else: _gathering_pos = Toolkit.rand_pos_in_rect(_safe_zone_rect)
		_wandering_time -= delta
	else: _set_state(State.SUPPORT)
func _retreat():
	if _has_apologized:
		velocity = _dir * _speed
		move_and_slide()
		if position.y <= _horizon_y or position.x <= -30 or position.x >= _screen_width + 30:
			_troop.remove_dead(self)
			queue_free()
func _apologize_movement():
	# play kneel down in _set_state()
	await Toolkit.wait(10)
	_has_apologized = true
	# play moving animation
func _die():
	# generate some blood
	await Toolkit.wait(3)
	_troop.remove_dead(self)
	queue_free()
func _change_size():
	var t = remap(global_position.y, _horizon_y, _most_y, 0.0, 1.0)
	var scale_value = lerp(min_scale, max_scale, t)
	scale = Vector2(scale_value, scale_value)
func _shock_soldier():
	# freeze them
	_set_both_process(false)
	_set_state(State.FREEZE)
	var wait_idx = await Toolkit.wait_timer_or_cancel(freeze_duration)
	match wait_idx:
		0:
			_set_both_process(true)
			if identity == Identity.SOLDIER:
				_set_state(State.MARCH)
		1: _set_state(State.APOLOGIZE)
		_: push_error("cancel signal wrong")
func murder(indi: Individual):
	if !is_commander:
		push_error("They isn't a commander!")
		return
	if state != State.SHOOT:
		_set_state(State.SHOOT) # just set state as a flag
		anim_sprite.play("s_shoot")
	else:
		anim_sprite.play("s_shoot_again")
	var idx = await Toolkit.wait_anim_or_cancel(anim_sprite)
	if idx == 0: 
		var sfx = AudioStreamPlayer2D.new()
		sfx.stream = gunshot_sfx.pick_random()
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())
		indi.on_get_shot() # nomral situation
	if idx == 1: 
		_set_state(State.APOLOGIZE)
		return
	if identity == Identity.SOLDIER and _troop._murder_queue.is_empty():
		_set_state(State.MARCH)
func _set_state(new_state : State):
	var pre_state = state
	if pre_state == State.APOLOGIZE: return
	state = new_state
	match identity:
		Identity.SOLDIER:
			match new_state:
				State.EMERGE: 
					pass 
					anim_sprite.play("s_emerge_from_horizon")
					var index = await Toolkit.wait_anim_or_cancel(anim_sprite)
					match index:
						0: 
							if identity == Identity.SOLDIER:
								_set_state(State.MARCH)
						1: _set_state(State.APOLOGIZE)
						_: push_error("wait_anim_or_cancel out of range")
				State.MARCH: 
					_set_both_process(true)
					anim_sprite.play("s_march")
				State.FREEZE: anim_sprite.play("s_freeze")
				State.SHOOT: pass
				State.APOLOGIZE: 
					_speed = retreat_speed
					_dir = Vector2.UP
					anim_sprite.play("s_drop_gun")
					await anim_sprite.animation_finished
					anim_sprite.play("s_kneel_down")
					await _apologize_movement()
					anim_sprite.play("s_retreat")
					_set_both_process(true)
				State.DIE: 
					_die()
				_:
					state = pre_state
					push_error("wrong state!")
		Identity.CIVILIAN:
			match new_state:
				State.FLEE: 
					anim_sprite.play("s_drop_gun")
					var idx = await Toolkit.wait_anim_or_cancel(anim_sprite)
					match idx:
						0:
							_has_gun = false
							anim_sprite.play("ca%d_flee" %ca_type)
							_troop.found_new_civilian_flee(self)
							_speed = flee_speed
						1: 
							await anim_sprite.animation_finished # still need the drop_gun animation finished
							_set_state(State.APOLOGIZE)
				State.APOLOGIZE: 
					_set_both_process(false)
					_speed = retreat_speed
					_dir = Vector2.UP
					anim_sprite.play("ca%d_kneel_down" %ca_type)
					await _apologize_movement()
					anim_sprite.play("ca%d_flee" %ca_type)
					_set_both_process(true)
				State.DIE: 
					anim_sprite.play("ca%d_die" %ca_type)
					await anim_sprite.animation_finished
					_die()
				_:
					state = pre_state
					push_error("wrong state: ", new_state, "pre state: ", pre_state)
		Identity.ACTIVIST:
			match new_state:
				State.WANDER: pass
				State.SUPPORT: 
					anim_sprite.play("ca%d_support" %ca_type)
					_set_both_process(false)
					emit_signal("became_real_activist", self)
				State.APOLOGIZE: 
					_set_both_process(false)
					_dir = Vector2.LEFT if _locating_left else Vector2.RIGHT
					_speed = wander_speed
					anim_sprite.play("ca%d_kneel_down" %ca_type)
					await _apologize_movement()
					anim_sprite.play("ca%d_flee" %ca_type)
					set_physics_process(true)
				State.DIE: 
					anim_sprite.play("ca%d_die" %ca_type)
					await anim_sprite.animation_finished
					_die()
				_:
					state = pre_state
					push_error("wrong state!")

func _check_bad_ending_line():
	if position.y > _most_y + bad_ending_line_y_offset:
		emit_signal("crossed_bad_ending_line")
		_troop.remove_dead(self)
		queue_free()
func on_get_shot():
	if identity == Identity.CIVILIAN:
		_set_state(State.DIE)
func on_enter_safe_zone():
	identity = Identity.ACTIVIST
	#print("enter safe zone")
func _on_stubbness_changed():
	match identity:
		Identity.SOLDIER:
			if stubbornness <= 0:
				identity = Identity.CIVILIAN
		Identity.CIVILIAN:
			var bonus = abs(stubbornness)
			_speed += bonus
		Identity.ACTIVIST:
			if _wandering_time > 0:
				_wandering_time -= abs(stubbornness)	
func _on_identity_changed(new_identity : Identity):
	match new_identity:
		Identity.CIVILIAN:
			# layer: 2, mask: 2 and 4
			set_collision_layer_value(2, true)
			set_collision_mask_value(2, true)
			set_collision_mask_value(4, true)
			set_collision_layer_value(1, false)
			set_collision_mask_value(1, false)
			set_collision_mask_value(3, false)
			# get the nearest gathering pot
			if position.distance_to(Data.left_gethering_pot) < position.distance_to(Data.right_gethering_pot):
				_gathering_pos = Data.left_gethering_pot
				_safe_zone_rect = Data.left_rect
				_locating_left = true
			else: 
				_gathering_pos = Data.right_gethering_pot
				_safe_zone_rect = Data.right_rect
				_locating_left = false
			is_commander = false
			_set_state(State.FLEE)
			_set_both_process(true)
		Identity.ACTIVIST:
			_gathering_pos = Toolkit.rand_pos_in_rect(_safe_zone_rect)
			_speed = wander_speed
			set_process(false)
			_set_state(State.WANDER)
			#print("I'm an wanderer!")
func on_good_ending():
	_set_state(State.APOLOGIZE)
func on_bad_ending():
	print("птн пнх")
func _set_both_process(value: bool):
	set_process(value)
	set_physics_process(value)	
