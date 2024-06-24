extends CharacterBody3D

@export_category("Movement Properties")
@export var movementSpeed : float = 5.0;
@export var movementJumpImpulse : float = 6.0;
@export var movementGravityAcceleration : float = -9.8;
var movementGravity : float = 0;

@export_category("Camera Properties")
@export var cameraObject : Camera3D;
@export var cameraLookSpeed : float = 2.0;
@export var cameraDistance : float = 2.5;
var cameraAngle : Vector2 = Vector2.ZERO;

@export_category("Other")

func _process(delta):
	# Get player input.
	var movementInput : Vector2 = Vector2(
		Input.get_axis("player_movement_rightward", "player_movement_leftward"),
		Input.get_axis("player_movement_backward", "player_movement_forward")
	);
	var cameraInput : Vector2 = Vector2(
		Input.get_axis("player_camera_right", "player_camera_left"),
		Input.get_axis("player_camera_up", "player_camera_down") # TODO: Inverted view axis.
	);
	
	# Move camera.
	cameraAngle += cameraInput * delta * cameraLookSpeed;
	if (cameraObject): 
		cameraObject.look_at_from_position(
			# Camera location.
			global_position + Vector3(
				-sin(cameraAngle.x) * cos(cameraAngle.y),
				sin(cameraAngle.y),
				-cos(cameraAngle.x) * cos(cameraAngle.y)
			) * cameraDistance,
			# Target object.
			global_position
		);
		
	# Get movement axis.
	var forwardMovement : Vector3 = Vector3(
		sin(cameraAngle.x),
		0,
		cos(cameraAngle.x)
	) * movementInput.y;
	var sideMovement : Vector3 = Vector3(
		cos(cameraAngle.x),
		0,
		-sin(cameraAngle.x)
	) * movementInput.x;
		
	# Update gravity.	
	var gravityFactor : float = movementGravityAcceleration * 0.5 * delta;
	
	# Handle jump / floor state.
	if (is_on_floor()):
		if (Input.is_action_just_pressed("player_movement_jump")):
			movementGravity = movementJumpImpulse;
		else:
			movementGravity = 0.0;
			gravityFactor = 0.0;
	
	# Use gravity.	
	movementGravity += gravityFactor;
	var verticalMovement : Vector3 = Vector3(
		0,
		movementGravity,
		0
	);
	movementGravity += gravityFactor;
	
	# Movement.
	var movement : Vector3 = ((forwardMovement + sideMovement) * movementSpeed) + verticalMovement;
	
	# Move.
	velocity = Vector3(movement.x, movement.y, movement.z);	
	move_and_slide();
