extends Collectable

func _ready():
	super._ready()
	connect("collected", _on_collected)

func _on_collected(body):
	body.receive_health(20)
