extends CharacterBody2D
class_name Individual
@onready var anim_sprite0: AnimatedSprite2D = $Sprite
var _horizon_y
var _most_y
var _speed : float
var _dir := Vector2.DOWN
var _gathering_pos : Vector2
var _safe_zone_rect : Rect2
var _wandering_time
var _troop : Troop
var is_commander : bool
var stubbornness : float :
	set(value):
		if value != stubbornness:
			stubbornness = value
			_on_stubbness_changed()
@export var base_speed: float = 5
@export var flee_speed: float = 20
@export var wander_speed: float = 30
@export var min_scale := 0.1
@export var max_scale := 2.0
@export var min_c_stub = 20
@export var max_c_stub = 100
@export var min_s_stub = 3
@export var max_s_stub = 20
@export_range(1, 10) var click_strength_multiplier := 2
@export var freeze_duration := 3.0
@export var base_wandering_time := 15.0
@export var randf_wandering_time := 2.0
enum Identity {SOLDIER, CIVILIAN, ACTIVIST}
enum State {MARCH, FREEZE, SHOOT, APOLOGIZE, FLEE, WANDER, SUPPORT, DIE}
var identity := Identity.SOLDIER :
	set(value):
		if value != identity:
			identity = value
			_on_identity_changed(value)
var state := State.MARCH
var anim_sprite : AnimatedSprite2D
signal became_real_activist(individual)
func _ready():
	_horizon_y = Data.horizon_y
	_most_y = Data.most_y
	_speed = base_speed
	_wandering_time = base_wandering_time + randf_range(-randf_wandering_time, randf_wandering_time)
	anim_sprite = anim_sprite0
	_set_state(State.MARCH)
func setup(commander_bool: bool, troop: Troop):
	is_commander = commander_bool
	_troop = troop
	stubbornness = randi_range(min_c_stub, max_c_stub) if is_commander else randi_range(min_s_stub, max_s_stub)
	#print(is_commander, " ", stubbornness)
func react_to_click(strength: int):
	_reduce_stubbornness(strength * click_strength_multiplier)
	if identity == Identity.SOLDIER:
		_shock_soldier()
func enter_no_to_war_zone(strength: int):
	_reduce_stubbornness(strength)
func _reduce_stubbornness(strength):
	stubbornness -= strength
	print(stubbornness)
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
		State.DIE:
			# play die anim and show the corpse for seconds
			_die()
			
func _process(_delta: float):
	_change_size()
	z_index = int(global_position.y)
func _march():
	velocity = _dir * _speed
	move_and_slide()
func _flee():
	# get the location and move to there
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
func _die():
	# generate some blood
	queue_free()
func _retreat():
	pass
func _change_size():
	var t = remap(global_position.y, _horizon_y, _most_y, 0.0, 1.0)
	var scale_value = lerp(min_scale, max_scale, t)
	scale = Vector2(scale_value, scale_value)
func _shock_soldier():
	# freeze them
	_set_both_process(false)
	_set_state(State.FREEZE)
	await get_tree().create_timer(freeze_duration).timeout
	_set_both_process(true)
	if identity == Identity.SOLDIER:
		_set_state(State.MARCH)
func _set_state(new_state : State):
	var pre_state = state
	state = new_state
	match identity:
		Identity.SOLDIER:
			match new_state:
				State.MARCH: anim_sprite.play("march")
				State.FREEZE: anim_sprite.play("freeze")
				State.SHOOT:
					if is_commander:
						# 
						pass #anim
					else:
						push_error("They isn't a commander!")
				State.APOLOGIZE: pass
				State.DIE: pass
				_:
					state = pre_state
					push_error("wrong state!")
		Identity.CIVILIAN:
			match new_state:
				State.FLEE: 
					# anim
					_troop.found_new_civilian_flee(self)
					_speed = flee_speed
					
				State.APOLOGIZE: pass
				State.DIE: pass
				_:
					state = pre_state
					push_error("wrong state: ", new_state, "pre state: ", pre_state)
		Identity.ACTIVIST:
			match new_state:
				State.WANDER: pass
				State.SUPPORT: 
					print("supporting!")
					_set_both_process(false)
					emit_signal("became_real_activist", self)
				State.APOLOGIZE: pass
				State.DIE: pass
				_:
					state = pre_state
					push_error("wrong state!")

func on_enter_safe_zone():
	identity = Identity.ACTIVIST
	print("enter safe zone")
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
			else: 
				_gathering_pos = Data.right_gethering_pot
				_safe_zone_rect = Data.right_rect
			_set_state(State.FLEE)
			_set_both_process(true)
			print("I'm a civilian!")
		Identity.ACTIVIST:
			_gathering_pos = Toolkit.rand_pos_in_rect(_safe_zone_rect)
			_speed = wander_speed
			set_process(false)
			_set_state(State.WANDER)
			print("I'm an wanderer!")

func _set_both_process(value: bool):
	set_process(value)
	set_physics_process(value)	
