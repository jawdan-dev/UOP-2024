extends Node3D

@export var menuHandler : Node3D;
func onTeleport(body : Node3D):
	if (menuHandler):
		menuHandler.call("gotoCredits");
	pass;
