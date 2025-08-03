extends Node2D
class_name Collectable

@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var area: Area2D = $area

signal collected(body: Node)

func _ready() -> void:
	area.body_entered.connect(_on_area_entered)
	sprite.play("default")

func _on_area_entered(body: Node) -> void:
	if body.name == "player":
		emit_signal("collected", body)
		sprite.play("collected")
		
		if not sprite.animation_finished.is_connected(_on_collected_animation_finished):
			sprite.animation_finished.connect(_on_collected_animation_finished)

func _on_collected_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_collected_animation_finished):
		sprite.animation_finished.disconnect(_on_collected_animation_finished)
		
	queue_free()
