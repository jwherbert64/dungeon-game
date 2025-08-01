extends Node2D
class_name Destructable

@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var static_body: StaticBody2D = $static_body
@onready var hitbox: CollisionShape2D = $static_body/hitbox
@onready var collectable_drop: Node = $collectable_drop

func _ready() -> void:
	static_body.add_to_group("destructables")

	# Use virtual method to determine animation
	if has_collectable():
		sprite.play("has_collectable")
	else:
		sprite.play("default")

func receive_damage(_damage: Damage) -> void:
	hitbox.set_deferred("disabled", true)
	sprite.play("destructing")

	if not sprite.animation_finished.is_connected(_on_destructing_animation_finished):
		sprite.animation_finished.connect(_on_destructing_animation_finished)

	if collectable_drop:
		collectable_drop.drop_collectable(global_position)

func _on_destructing_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_destructing_animation_finished):
		sprite.animation_finished.disconnect(_on_destructing_animation_finished)

	queue_free()

# Virtual method to allow override
func has_collectable() -> bool:
	return collectable_drop != null
