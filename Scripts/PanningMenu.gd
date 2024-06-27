extends Node3D

func _process(delta):
	rotation.y += delta * TAU / 20.0;
