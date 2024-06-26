extends Area3D

@export var player : Node3D;

func _onPlayerHit(body : Node3D):
	if (player): 
		player.call("resetPlayer");


