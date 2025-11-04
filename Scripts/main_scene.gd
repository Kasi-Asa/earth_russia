extends Node2D
class_name MainScene
@onready var middle: Node2D = $Middle
@onready var left: Area2D = $Left
@onready var right: Area2D = $Right

var horizon_y : float
var middle_width : float
var side_width : float
var screen_size
var left_rect
var right_rect
const DESIGN_SIZE = Vector2(1920, 1080)
var sky_color : Color = Color("#0057B7")
var ground_color : Color = Color("#FFD700")

# collision layers:
# soldier 1, civilian 2, wall 3, safe zone 4
func _ready():
	# background sizing
	screen_size = DESIGN_SIZE
	var middle_height = screen_size.y
	middle_width = middle_height * (3.0 / 2.0)
	side_width = (screen_size.x - middle_width) / 2.0
	horizon_y = middle_height / 2.0
	
	# background position
	middle.position = Vector2(side_width, 0)
	left.position = Vector2(0, 0)
	right.position = Vector2(side_width + middle_width, 0)
	
	# set collision shapes
	var side_size = Vector2(side_width, middle_height)
	for collider in get_tree().get_nodes_in_group("Colliders"):
		var shape = collider.shape
		if shape is RectangleShape2D:
			shape.extents = side_size / 2
			collider.shape = shape
			collider.position = shape.extents
			
	# prepare rects for safe zone
	left_rect = Rect2(left.position, side_size)
	right_rect = Rect2(right.position, side_size)
	
	queue_redraw()
	
func _draw():
	draw_rect(Rect2(0, 0, screen_size.x, screen_size.y), Color.BLACK)
	draw_rect(Rect2(side_width, 0, middle_width, horizon_y), sky_color)
	draw_rect(Rect2(side_width, horizon_y, middle_width, horizon_y), ground_color)
