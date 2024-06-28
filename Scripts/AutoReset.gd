extends CanvasLayer

@export var timeout : float = 90.0;
@export var visualThreshold : float = 30.0;

@onready var remainingTime : float = timeout;
@onready var baseString : String = $ColorRect/Label.text;

func _process(delta):
	# Update time.
	if (!GameState.gameActive || Input.is_anything_pressed()):
		# Iteraction!! Yippeeee!
		remainingTime = timeout;
	else:
		# No intentional interaction in delta seconds.
		remainingTime -= delta;
	
	# Reset game.
	if (remainingTime <= 0 || Input.is_action_just_pressed("config_restart_game")):
		get_tree().change_scene_to_file("res://Scenes/SplashScreen.tscn");
		
	# Update visuals.
	elif (remainingTime <= visualThreshold):
		visible = true;
		$ColorRect/Label.text = baseString.replace("%s", String.num(floor(remainingTime), 0));
	else:
		visible = false;
