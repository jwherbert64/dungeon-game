extends Enemy

var drop_enabled: bool = false

func _ready():
	initial_health = 60
	health = initial_health
	damage_amount = 20
	has_direction = true
	last_direction = "front"
	has_attacking_anim = true
	
	# Decide before base class logic runs
	if has_node("collectable_drop"):
		if randf() < 1.0:
			drop_enabled = true
			collectable_drop.drop_scene = preload("res://scenes/collectables/health_collectable/health_collectable.tscn")
		else:
			collectable_drop.queue_free()
	
	super._ready()

# Override virtual method
func has_collectable() -> bool:
	return drop_enabled
