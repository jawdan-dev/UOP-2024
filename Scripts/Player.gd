extends CharacterBody3D

@export_category("Movement Properties")
# Ground.
@export var movementSpeed : float = 5.0;
# Jump.
@export var movementJumpImpulseMax : float = 4.0;
@export var movementJumpImpulseMin : float = 2.0;
@export var movementJumpHoldTimeMax : float = 0.3;
var movementJumpHoldTimeRemaining : float = 0;
@export var movementJumpCoyoteTime : float = 0.2;
var movementTimeSinceLastJump : float = 0.0;
var movementTimeSinceLastGrounded : float = 0.0;
# Gravity.
@export var movementGravityAcceleration : float = -9.8;
var movementGravity : float = 0;

@export_category("Camera Properties")
@export var cameraObject : Camera3D;
@export var cameraLookSpeed : float = 2.0;
@export var cameraDistance : float = 2.5;
var cameraAngle : Vector2 = Vector2.ZERO;

@export_category("Other")

func _process(delta):		
	# Handle gravity.
	handleGravity(delta);
	# Handle movement.
	handleMovement(delta);
	
	# Handle camera.
	handleCamera(delta);
	
	# Movement.
	var totalMovement : Vector3 = ((forwardMovement + sideMovement) * movementSpeed) + verticalMovement;
	velocity = totalMovement;	
	# Move!
	move_and_slide();

################################################################################

func handleCamera(delta):
	# Get player input.
	var cameraInput : Vector2 = Vector2(
		Input.get_axis("player_camera_right", "player_camera_left"),
		Input.get_axis("player_camera_up", "player_camera_down") # TODO: Inverted view axis.
	);
	
	# Move camera.
	cameraAngle += cameraInput * delta * cameraLookSpeed;
	
	# Clamp angles.
	const cameraMaxExtent = TAU * 0.25 * 0.9;
	cameraAngle.y = clampf(cameraAngle.y, -cameraMaxExtent, cameraMaxExtent);
	
	# Update camera object.
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


################################################################################

var forwardMovement : Vector3;
var sideMovement : Vector3;
func handleMovement(delta):
	# Get player input.
	var movementInput : Vector2 = Vector2(
		Input.get_axis("player_movement_rightward", "player_movement_leftward"),
		Input.get_axis("player_movement_backward", "player_movement_forward")
	);
	
	# Handle forward movement.
	forwardMovement = Vector3(
		sin(cameraAngle.x),
		0,
		cos(cameraAngle.x)
	) * movementInput.y;
	
	# Handle side movement.
	sideMovement = Vector3(
		cos(cameraAngle.x),
		0,
		-sin(cameraAngle.x)
	) * movementInput.x;

################################################################################

var verticalMovement : Vector3;
func handleGravity(delta):
	# Handle gravity variables.
	movementTimeSinceLastJump += delta;
	movementTimeSinceLastGrounded += delta;
		
	# Update gravity.	
	var gravityFactor : float = movementGravityAcceleration * 0.5 * delta;
	
	# Handle floor factor.
	if (is_on_floor()): 
		movementTimeSinceLastGrounded = 0.0;
		movementGravity = 0.0;
		gravityFactor = 0.0;
	
	# Handle jump.
	if (Input.is_action_just_pressed("player_movement_jump") && \
		movementTimeSinceLastGrounded < movementJumpCoyoteTime && \
		movementTimeSinceLastGrounded < movementTimeSinceLastJump):
		# Jump!
		movementTimeSinceLastJump = 0.0;
		movementGravity = movementJumpImpulseMax;
		movementJumpHoldTimeRemaining = movementJumpHoldTimeMax;
		
	# Handle jump hold.
	if (movementJumpHoldTimeRemaining > 0):
		if (Input.is_action_pressed("player_movement_jump")):
			# Run out.
			movementGravity = movementJumpImpulseMax
			movementJumpHoldTimeRemaining -= delta;
		else:
			# Let go.
			if (movementGravity > 0):
				movementGravity = lerp(movementJumpImpulseMin, movementJumpImpulseMax, 1 - (movementJumpHoldTimeRemaining / movementJumpHoldTimeMax));
			movementJumpHoldTimeRemaining = 0;		
	
	# Use gravity.	
	movementGravity += gravityFactor;
	verticalMovement = Vector3(
		0,
		movementGravity,
		0
	);
	movementGravity += gravityFactor;

################################################################################
