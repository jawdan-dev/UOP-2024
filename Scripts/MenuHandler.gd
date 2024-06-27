extends Node3D

@export var cameraObject : Camera3D;
@onready var cameraObjectA : Node3D = $PanningCameraTarget;
@export var cameraObjectB : Node3D;

var cameraMix : float = 0.0;
@export var lerpCamera : bool = false;
@export var lerpCameraSpeedTo : float = 2;
@export var lerpCameraSpeedFrom : float = 10;

@export var resetScene : PackedScene;

var menuState : MenuState = MenuState.MenuState_Menu;
enum MenuState {
	MenuState_None,
	MenuState_Menu,
	MenuState_Credits,
};

func _process(delta):
	if (!cameraObject || !cameraObjectA || !cameraObjectB): return;
	
	# Lerp when not in menu.
	lerpCamera = menuState == MenuState.MenuState_None;
	
	match (menuState):
		MenuState.MenuState_None:
			$Menu.visible = false;
			$Credits.visible = false;
			GameState.gameActive = true;			
			
		MenuState.MenuState_Menu:
			$Menu.visible = true;
			$Credits.visible = false;
			GameState.gameActive = false;			
			
			if (Input.is_action_just_pressed("player_combat_dive") || Input.is_action_just_pressed("player_movement_jump")):
				menuState = MenuState.MenuState_None;
				
		MenuState.MenuState_Credits:
			$Menu.visible = false;
			$Credits.visible = true;
			GameState.gameActive = false;			
			if (Input.is_action_just_pressed("player_combat_dive") || Input.is_action_just_pressed("player_movement_jump")):
				if (resetScene):
					get_tree().change_scene_to_packed(resetScene);
			
	
	# Rotation bby.
	rotation.y += delta * TAU * 0.05;
	
	# Lerp Camera.
	cameraMix = clampf(cameraMix + (delta / (lerpCameraSpeedTo if lerpCamera else -lerpCameraSpeedFrom)), 0.0, 1.0);
		
	cameraObject.global_position = lerp(cameraObjectA.global_position, cameraObjectB.global_position, cameraMix);
	cameraObject.global_rotation = lerp(cameraObjectA.global_rotation, cameraObjectB.global_rotation, cameraMix);
	

func gotoCredits():
	menuState = MenuState.MenuState_Credits;
