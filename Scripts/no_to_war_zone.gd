extends Area2D
@export var strength := 1
func _ready():
	body_entered.connect(_on_body_entered)
func _on_body_entered(body):
	if body is Individual:
		body.enter_no_to_war_zone(strength)
