extends Control

@export var splashTime : float = 1.5;

@export var splashList : Node;

var remainingSplash : float = 0.0;
var activeSplash : int = -1;
func _ready():
	if (splashList):
		for c in splashList.get_children():
			c.visible = false;

func _process(delta):
	if (!splashList): return;
	
	if (remainingSplash <= 0.0):
		splashList.get_child(activeSplash).visible = false;;
		activeSplash += 1;
		remainingSplash = splashTime;
	else:
		remainingSplash -= delta;
	
	if (activeSplash >= splashList.get_child_count()):
		get_tree().change_scene_to_file("res://Scenes/Game.tscn");
	else:
		splashList.get_child(activeSplash).visible = true;
	

