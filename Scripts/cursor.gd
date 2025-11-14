extends Node2D
@onready var game_manager: Node = $"../GameManager"
@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_stream_player: AudioStreamPlayer2D = $"../AudioStreamPlayer2D"
@export var no_to_war_zone_scene: PackedScene
@export var no_to_war_texture_arr : Array[Texture2D]
@export var mouse_radius := 100.0 # unused rn
@export var min_scale := 0.1
@export var max_scale := 2.0
@export var no_to_war_audio : Array[AudioStream]
var cold_duration := 3.0
var _tick := 0.0
var _is_ready_to_click := true :
	set(value):
		if value != _is_ready_to_click:
			_is_ready_to_click = value
			_debug_color = Color.BLUE if value else Color.RED
var _mouse_pos : Vector2
var _sprite_size
var _horizon_y
var _most_y
var _debug_color := Color.BLUE
func _ready():
	await get_parent().ready
	_horizon_y = Data.horizon_y
	_most_y = Data.most_y
	_set_texture()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Toolkit.cancel_signal.connect(_on_ending)
func _process(delta):
	_mouse_pos = get_global_mouse_position()
	sprite.position = _mouse_pos
	var half_height = _change_sprite_size()
	if !_is_ready_to_click:
		if _tick <= cold_duration:
			_tick += delta
			var p = remap(_tick, 0, cold_duration, 0.0, 1.0)
			sprite.material.set_shader_parameter("progress", p)
		else:
			_is_ready_to_click = true
	sprite.z_index = sprite.global_position.y + half_height * 2
	#queue_redraw()
#func _draw(): # debug
	#draw_rect(Rect2(_mouse_pos, sprite.texture.get_size() * sprite.scale), _debug_color, false, 2.0)
	#draw_circle(Vector2(_mouse_pos.x, sprite.z_index), 5.0, Color.RED)
func _change_sprite_size() -> float:
	var cal_pot_y = _mouse_pos.y
	if _mouse_pos.y < _horizon_y:
		cal_pot_y = _most_y - cal_pot_y # mirror (the pos over horizon)
	var t = remap(cal_pot_y, _horizon_y, _most_y, 0.0, 1.0)
	var scale_value = lerp(min_scale, max_scale, t)
	sprite.scale = Vector2(scale_value, scale_value)
	_sprite_size = sprite.texture.get_size() * scale_value
	return _sprite_size.y / 2.0
# input
func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed() and _is_ready_to_click:
		_is_ready_to_click = false
		_tick = 0
		var bodies = _get_bodies_in_rect(_mouse_pos, sprite.texture.get_size() * sprite.scale)
		for b in bodies:
			if b.collider is Individual:
				b.collider.react_to_click(game_manager.activist_strength)
		_create_no_to_war_zone()
		_set_texture()
		audio_stream_player.stream = no_to_war_audio.pick_random()
		audio_stream_player.play()
func _get_bodies_in_rect(center: Vector2, size: Vector2) -> Array:
	var space_state = get_world_2d().direct_space_state
	var rect = RectangleShape2D.new()
	rect.size = size
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0, center)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space_state.intersect_shape(query)
	return result
func _create_no_to_war_zone():
	var zone = no_to_war_zone_scene.instantiate() as Area2D
	get_tree().current_scene.add_child(zone)
	zone.global_position = _mouse_pos
	var clone_sprite = sprite.duplicate() as Sprite2D
	zone.add_child(clone_sprite)
	clone_sprite.global_position = sprite.global_position
	clone_sprite.material = null
	var collision = zone.get_node("CollisionShape2D") as CollisionShape2D
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = _sprite_size
	collision.shape = rect_shape
func _set_texture():
	var tex = no_to_war_texture_arr.pick_random()
	sprite.texture = tex
func _on_ending():
	set_process(false)
	_is_ready_to_click = false
# debug
#func _input(event):
	#if event is InputEventKey and event.is_pressed():
		#print("pressed")
		#Toolkit.cancel_signal.emit()
