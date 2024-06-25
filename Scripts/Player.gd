extends CharacterBody3D

@export_category("Movement Properties")
# Momentum
@export var movementFactorGround : float = 12;
@export var movementFactorAir : float = 8;
@export var movementMomentumDampeningGround : float = 16;
@export var movementMomentumDampeningAir : float = 3;
var movementMomentum : Vector3 = Vector3.ZERO;
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

@export_category("Combat")
@export var combatEntitiesList : Node;
@export_range(-1, 1) var combatLookingDotThreshold : float = 0.7;
@export var combatEngageDistance : float = 10;

@export_category("Other")

func _process(delta):		
	# Handle gravity.
	handleGravity(delta);
	# Handle movement.
	handleMovement(delta);
	# Handle momentum.
	handleMomentum(delta);
	# Move!
	var totalMovement : Vector3 = movementMomentum + verticalMovement;
	velocity = totalMovement;	
	move_and_slide();
	
	# Handle camera.
	handleCamera(delta);
	# Handle combat.
	handleCombat(delta);
	

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

func handleMomentum(delta):
	# Update momentum.
	var grounded : bool = is_on_floor();
	var horizontalMovement : Vector3 = ((forwardMovement + sideMovement) * movementSpeed)
	if (horizontalMovement.length_squared() > 0):
		# Maintain.
		movementMomentum = movementMomentum.move_toward(horizontalMovement, (movementFactorGround if grounded else movementFactorAir) * delta);
	else:
		# Dampen.
		movementMomentum = movementMomentum.move_toward(Vector3.ZERO, (movementMomentumDampeningGround if grounded else movementMomentumDampeningAir) * delta)

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

var activeCombatEntity : Node3D;
func handleCombat(delta): 
	# Safety first.
	if (!combatEntitiesList || !cameraObject): return;
	
	# Get list of entites.
	var entities : Array[Node] = combatEntitiesList.get_children(false)
	
	# Calculation variables.
	var combatEngageDistanceSquared : float = combatEngageDistance * combatEngageDistance;
	var lookingDirection : Vector3 = Vector3(
		sin(cameraAngle.x) * cos(cameraAngle.y),
		-sin(cameraAngle.y),
		cos(cameraAngle.x) * cos(cameraAngle.y)
	);
	
	# Get entity that is being looked at.
	var bestDot : float = -1.1;
	var bestEntity : Node3D = null;
	for e : Node3D in entities:
		if (!e): continue;
		# Check distance to entity.
		var eDifference : Vector3 = e.global_position - cameraObject.global_position;
		if (eDifference.length_squared() > combatEngageDistanceSquared): continue;
		# Get direction & dot to entity.
		var eDirection : Vector3 = eDifference.normalized();
		var eDot : float = lookingDirection.dot(eDirection)
		
		# Compare to best.
		if (bestDot >= eDot && bestEntity != null): continue;
		
		# TODO: Raycast?
		
		# Set as best.
		bestEntity = e;
		bestDot = eDot;
	
	# Set active combat entity.
	if (bestDot >= combatLookingDotThreshold):
		activeCombatEntity = bestEntity;
	else:
		activeCombatEntity = null;
		
	# Handle lock.
	if (!activeCombatEntity):
		$CombatLock.visible = false;
	else:
		$CombatLock.visible = true;
		$CombatLock.global_position = activeCombatEntity.global_position;
	
################################################################################
