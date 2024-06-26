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
@onready var cameraObject : Camera3D = $MainCamera;
@export var cameraTargetOffset : Vector3 = Vector3.ZERO;
@export var cameraLookSpeed : float = 2.0;
@export var cameraDistance : float = 2.5;
var cameraAngle : Vector2 = Vector2.ZERO;

@export_category("Combat")
# Entity target selection.
@export var combatEntitiesList : Node;
@export_range(-1, 1) var combatLookingDotThreshold : float = 0.7;
@export var combatEngageDistance : float = 10;
# Knockback.
@export var combatKnockbackDampening : float = 8;
var combatKnockback : Vector3 = Vector3.ZERO;

# Dive attack.
@export var combatDiveSpeed : float = 16;
@export var combatDiveBounceImpulse : float = 8;
@export var combatDiveMomentumImpulse : float = 5;

@export_category("Other")
@export var animationOrigin : Node3D;
@export var animationPlayer : AnimationPlayer;
@export var animationAirObject : Node3D;

enum PlayerState {
	PlayerState_Moving, 
	PlayerState_Combat_Diving,
};

var playerState : PlayerState = PlayerState.PlayerState_Moving;
var hitEntity : Node3D = null;
func _physics_process(delta):
	# Handle gravity.
	handleGravity(delta);
	# Handle movement.
	handleMovement(delta);
	# Handle momentum.
	handleMomentum(delta);
	# Hanlde knockback.
	handleKnockback(delta);
	
	var totalMovement : Vector3 = movementMomentum + verticalMovement + combatKnockback
	match (playerState): 
		PlayerState.PlayerState_Moving: 
			# Handle combat.
			handleCombat(delta);
			
			# Combat scuff.
			if (Input.is_action_just_pressed("player_combat_dive") && activeCombatEntity != null):
				playerState = PlayerState.PlayerState_Combat_Diving;
				
			# Rotate towards momentum.
			if (animationOrigin): animationOrigin.look_at(animationOrigin.global_position - movementMomentum);
			# Base animation.
			if (verticalMovement.y != 0):
				playAnimation("Air");
				setAnimationPercentage( \
					 clamp(remap(verticalMovement.y, 10.0, -10.0, 0.0, 1.0), 0.0, 1.0)
				);
			elif (movementMomentum.length_squared() > 0):
				playAnimation("Running");
				# Set run animation speed based on movement speed.
				setAnimationSpeed(movementMomentum.length() / movementSpeed);
			else:
				playAnimation("Idle");
				

			# Hide air.	
			if (animationAirObject && animationAirObject.visible): animationAirObject.visible = false;
			
		PlayerState.PlayerState_Combat_Diving: 
			if (!activeCombatEntity || is_on_floor() || is_on_wall() || is_on_ceiling()):
				playerState = PlayerState.PlayerState_Moving;
				pass;
			
			# Get target distance stuff.
			var dif : Vector3 = activeCombatEntity.global_position - global_position;
			var len : float = dif.length();
			
			# Play dive animation.
			playAnimation("Dive");
			if (animationAirObject && !animationAirObject.visible): animationAirObject.visible = true;
			if (animationOrigin): animationOrigin.look_at(animationOrigin.global_position - (activeCombatEntity.global_position - animationOrigin.global_position));
			
			# Check if tar
			if (hitEntity):
				# Attack finished.
				playerState = PlayerState.PlayerState_Moving;
				
				# Bounce off of enemy.
				movementGravity = combatDiveBounceImpulse;
				var reverseAction : Vector3 = -dif.normalized() * combatDiveMomentumImpulse;
				movementMomentum = Vector3(reverseAction.x, 0, reverseAction.z);
				totalMovement = movementMomentum + verticalMovement + combatKnockback
				
				# Entity knockback.
				hitEntity.set("combatKnockback", hitEntity.get("combatKnockback") + -reverseAction + Vector3(0, 2, 0));
				
				# Reset.
				hitEntity = null;
			else:
				# Move towards target.
				totalMovement = (dif / len) * combatDiveSpeed;
	
	# Move!
	velocity = totalMovement;	
	move_and_slide();
	
	# Handle camera.
	handleCamera(delta);
	
	# Update combat mark.
	updateCombatMark(delta);

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
			global_position + cameraTargetOffset + Vector3(
				-sin(cameraAngle.x) * cos(cameraAngle.y),
				sin(cameraAngle.y),
				-cos(cameraAngle.x) * cos(cameraAngle.y)
			) * cameraDistance,
			# Target object.
			global_position + cameraTargetOffset
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

func handleKnockback(delta): 
	combatKnockback = combatKnockback.move_toward(Vector3.ZERO, combatKnockbackDampening * delta);

var activeCombatEntity : Node3D;
func handleCombat(delta): 
	# Safety first.
	if (!combatEntitiesList || !cameraObject || is_on_floor()): 
		activeCombatEntity = null;
		return;
	
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
		

func updateCombatMark(delta):
	# Handle mark.
	if (!activeCombatEntity):
		$CombatMark.visible = false;
	else:
		$CombatMark.visible = true;
		$CombatMark.global_position = activeCombatEntity.global_position;

func _onEntityHit(entity : Node3D):
	hitEntity = entity;

################################################################################

func playAnimation(animation : String):
	# Safety first.
	if (!animationPlayer || !animationPlayer.has_animation(animation)): 
		return;	
	
	# Set new animation if not already set.
	if (animationPlayer.get_current_animation() == animation): return;
	animationPlayer.set_current_animation(animation);
		
	# Make sure the animation starts playing.
	if (!animationPlayer.is_playing()):
		animationPlayer.play();
	
	# Reset speed scale.
	animationPlayer.speed_scale = 1.0;

func setAnimationPercentage(percentage : float):
	# Safety first.
	if (!animationPlayer): 
		return;
	
	# Make sure the animation is paused.
	if (animationPlayer.is_playing()):
		animationPlayer.pause();
	
	# Set animation percentage.
	animationPlayer.seek(percentage * animationPlayer.current_animation_length);
	
func setAnimationSpeed(percentage : float):
	# Safety first.
	if (!animationPlayer): 
		return;
		
	# Set speed scale.
	animationPlayer.speed_scale = percentage;
	
################################################################################
	
