extends Node2D
@onready var game_manager: Node = $"../GameManager"
@export var mouse_radius := 100.0
var cold_duration := 3.0
var _tick := 0.0
var _is_ready_to_click := true :
	set(value):
		if value != _is_ready_to_click:
			_is_ready_to_click = value
			_circle_color = Color.BLUE if value else Color.RED
var _mouse_pos : Vector2
var _circle_color := Color.BLUE
func _process(delta):
	_mouse_pos = get_global_mouse_position()
	if !_is_ready_to_click:
		if _tick <= cold_duration:
			_tick += delta
		else:
			_is_ready_to_click = true
	queue_redraw()
func _draw():
	draw_circle(_mouse_pos, mouse_radius, _circle_color, false, 2.0)
# input
func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed() and _is_ready_to_click:
		_is_ready_to_click = false
		_tick = 0
		var bodies = _get_bodies_in_circle(_mouse_pos, mouse_radius)
		for b in bodies:
			if b.collider is Individual:
				b.collider.react_to_click(game_manager.activist_strength)
func _get_bodies_in_circle(center: Vector2, radius: float) -> Array:
	var space_state = get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0, center)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space_state.intersect_shape(query)
	return result
