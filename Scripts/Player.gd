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
@export var cameraObject : Node3D;
@export var cameraTargetOffset : Vector3 = Vector3.ZERO;
@export var cameraLookSpeed : float = 2.0;
@export var cameraDistance : float = 2.5;
var cameraAngle : Vector2 = Vector2(TAU * 0.5, TAU * 0.1);

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
@export var combatDiveIgnoreDamageTimer : float = 0.5;

@export_category("Animation")
@export var animationOrigin : Node3D;
@export var animationPlayer : AnimationPlayer;
@export var animationAirObject : Node3D;

@export_category("Other")
@export var resetPoints : Node;
var entityIgnoreGround : bool = false;
var entityIgnoreGroundCooldown : float = 0.0;
var ignoreDamageTimer = 0.0;
var canDive : bool = true;

enum PlayerState {
	PlayerState_Moving, 
	PlayerState_Combat_Diving,
};

func _ready():
	for rp in resetPoints.get_children():
		rp.visible = false;	

var playerState : PlayerState = PlayerState.PlayerState_Moving;

func _physics_process(delta):
	# Game's paused, stop.
	setAnimationPaused(GameState.gamePaused);
	if (GameState.gamePaused): return;
		
	# Handle gravity.
	handleGravity(delta);
	# Handle movement.
	handleMovement(delta);
	# Handle momentum.
	handleMomentum(delta);
	# Handle knockback.
	handleKnockback(delta);
	
	# Handle entity buffering.
	if (hitBuffer.size() > 0 && hitEntity == null):
		hitEntity = hitBuffer.pop_front();

	var totalMovement : Vector3 = movementMomentum + verticalMovement + combatKnockback
	match (playerState): 
		PlayerState.PlayerState_Moving: 
			# Handle combat.
			handleCombat(delta);
			
			# Contact damage.
			if (hitEntity != null && ignoreDamageTimer <= 0.0):
				var damage : float = hitEntity.get("combatContactDamage");
				if (damage > 0):
					var knockbackDirection : Vector3 = hitEntity.global_position.direction_to(global_position) * 10.0;
					combatKnockback = Vector3(knockbackDirection.x, 2.0, knockbackDirection.z);
					iFrameTimeRemaining = 1.0;
					pass;
			
			if (!canDive && is_on_floor()):
				canDive = true;
			# Combat scuff.
			#if (Input.is_action_just_pressed("player_combat_dive") && activeCombatEntity != null):
			if (Input.is_action_just_pressed("player_combat_dive") && !is_on_floor() && canDive):
				if (activeCombatEntity == null):
					#no enemy found so we gonna birth one
					var movement : Vector3 = -(forwardMovement + sideMovement)
					if movement.length_squared() > 0:
						$VirtualEnemy.position = (movement).normalized()* 69
						activeCombatEntity = $VirtualEnemy
						entityIgnoreGround = true;
						entityIgnoreGroundCooldown = 0.5;
						canDive = false;
						playerState = PlayerState.PlayerState_Combat_Diving;
				else:
					playerState = PlayerState.PlayerState_Combat_Diving;
			# Rotate towards momentum.
			if (animationOrigin && movementMomentum.length_squared() > 0): animationOrigin.look_at(animationOrigin.global_position - movementMomentum);
			# Base animation.
			if (verticalMovement.y != 0):
				playAnimation("Air");
				setAnimationPercentage( \
					 clamp(remap(verticalMovement.y, movementJumpImpulseMax + 2.0, -10.0, 0.0, 1.0), 0.0, 1.0)
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
			ignoreDamageTimer = combatDiveIgnoreDamageTimer;
			
			if (!activeCombatEntity):
				playerState = PlayerState.PlayerState_Moving;
				entityIgnoreGround = false;
				return;
			
			# Get target distance stuff.
			var dif : Vector3 = activeCombatEntity.global_position - global_position;
			var len : float = dif.length();
			
			# Play dive animation.
			playAnimation("Dive");
			if (animationAirObject && !animationAirObject.visible): animationAirObject.visible = true;
			if (animationOrigin): animationOrigin.look_at(animationOrigin.global_position - (activeCombatEntity.global_position - animationOrigin.global_position));
			
			# Check if target hit
			if (hitEntity):
				# Attack finished.
				playerState = PlayerState.PlayerState_Moving;
				# TODO: Reset player direction to be straight...
				
				# Bounce off of enemy.
				movementGravity = combatDiveBounceImpulse;
				var reverseAction : Vector3 = -dif.normalized();
				movementMomentum = Vector3(reverseAction.x, 0, reverseAction.z) * combatDiveMomentumImpulse;
				totalMovement = movementMomentum + verticalMovement + combatKnockback
				
				
				# Entity knockback.
				hitEntity.set("combatKnockback", hitEntity.get("combatKnockback") + -(Vector3(reverseAction.x, 0, reverseAction.z).normalized() * combatDiveMomentumImpulse) + Vector3(0, 2, 0));
				hitEntity.call("_onDamageHit", 1);
			else:
				if (entityIgnoreGround && entityIgnoreGroundCooldown - delta < 0):
					playerState = PlayerState.PlayerState_Moving;
					entityIgnoreGround = false;
					movementGravity = 0;
				elif ((is_on_floor() || is_on_wall() || is_on_ceiling()) && !entityIgnoreGround):
					entityIgnoreGround = true;
					entityIgnoreGroundCooldown = 0.35;
					
				if (entityIgnoreGroundCooldown > 0 ): entityIgnoreGroundCooldown -= delta;
				
				# Move towards target.
				totalMovement = (dif / len) * combatDiveSpeed;
	
	# Move!
	velocity = totalMovement;	
	move_and_slide();
	
	# Handle camera.
	handleCamera(delta);
	
	# Update combat mark.
	updateCombatMark(delta);
	
	# Reset point updating.
	handleResetPoint(delta);

	# Manual player reset.
	if (Input.is_action_just_pressed("player_reset")):
		resetPlayer();
	
	# IDK, magic i guess.
	handleIFrames(delta);
	if (ignoreDamageTimer > 0.0): ignoreDamageTimer -= delta;

################################################################################

@export_category("iFrames")
@export var iFrameMesh : MeshInstance3D;
var iFrameShader : Shader = preload("res://Shaders/WorldShaderIFrame.gdshader");
var iFrameTimeRemaining : float = 0.0;
var baseShader : Shader;
func handleIFrames(delta):
	if (!iFrameMesh || !iFrameShader): return;
	# Get material.
	var mat : ShaderMaterial = iFrameMesh.material_override as ShaderMaterial;
	if (!mat): return;
	
	if (iFrameTimeRemaining > 0):
		iFrameTimeRemaining -= delta;
		if (mat.shader != iFrameShader):
			baseShader = mat.shader;
			mat.shader = iFrameShader;
	elif (mat.shader == iFrameShader):
			mat.shader = baseShader;	

################################################################################

func handleCamera(delta):
	if (!GameState.gameActive): return;
	
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
	if (!GameState.gameActive):
		forwardMovement = Vector3.ZERO;
		sideMovement = Vector3.ZERO;
		return;
		
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
	if (is_on_floor() && movementGravity <= 0): 
		movementTimeSinceLastGrounded = 0.0;
		movementGravity = 0.0;
		gravityFactor = 0.0;
		
	if (is_on_ceiling() && movementGravity > 0):
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
	var grounded : bool = is_on_floor();
	combatKnockback = combatKnockback.move_toward(Vector3.ZERO, combatKnockbackDampening * delta);
	if (grounded): combatKnockback.y = 0;

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
		if ((bestDot >= eDot && bestEntity != null) || \
			e.get("iFrameTimeRemaining") > 0.0): continue;
		
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
	if (!activeCombatEntity || activeCombatEntity == $VirtualEnemy):
		$CombatMark.visible = false;
	else:
		$CombatMark.visible = true;
		$CombatMark.global_position = activeCombatEntity.global_position;

var hitEntity : Node3D = null;
var hitBuffer : Array[Node3D] = [];
func _onEntityHit(e : Node3D):
	var entity : Node3D = e.get_parent();
	
	if (hitEntity == null):
		hitEntity = entity;
	else:
		hitBuffer.push_back(entity);

func _onEntityUnhit(e : Node3D):
	var entity : Node3D = e.get_parent();
	
	if (hitEntity == entity):
		hitEntity = null;
		return;
		
	var idx : int = hitBuffer.find(entity);
	if (idx != -1):
		hitBuffer.remove_at(idx);

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

func setAnimationPaused(paused : bool):
	# Safety first.
	if (!animationPlayer): return; 
	
	if (paused && animationPlayer.is_playing()):
		animationPlayer.pause();
	elif (!paused && !animationPlayer.is_playing()):
		animationPlayer.play();
		
func setAnimationPercentage(percentage : float):
	# Safety first.
	if (!animationPlayer): 
		return;
	
	# Make sure the animation is paused.
	if (animationPlayer.is_playing()):
		animationPlayer.pause();
	
	# Set animation percentage.
	animationPlayer.seek(percentage * animationPlayer.current_animation_length * 0.98);
	
func setAnimationSpeed(percentage : float):
	# Safety first.
	if (!animationPlayer): 
		return;
		
	# Set speed scale.
	animationPlayer.speed_scale = percentage;
	
################################################################################
	
@onready var lastValidResetPoint : Vector3 = global_position;
func handleResetPoint(delta):
	if (!resetPoints): return; # Handle this case?
	
	# Check if fully grounded.
	if (!is_on_floor() || movementGravity > 0): return;
	
	
	# Find closest reset point.
	var bestDist : float = INF;
	var bestPoint : Node3D = null;
	for rp in resetPoints.get_children():
		var point = rp as Node3D;
		if (!point): continue;
		var dist = point.global_position.distance_to(global_position);
		if (!bestPoint || dist < bestDist):
			bestPoint = point;
			bestDist = dist;
	
	# Update last reset point.
	if (bestPoint):
		lastValidResetPoint = bestPoint.global_position;

func resetPlayer():
	# TODO: Deal damage here.
	
	if (playerState == PlayerState.PlayerState_Combat_Diving):
		entityIgnoreGround = true;
	
	global_position = lastValidResetPoint;

################################################################################
