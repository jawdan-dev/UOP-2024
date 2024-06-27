extends CharacterBody3D

@export_category("Movement Properties")
@export var movementUseMovement : bool = true;
# Momentum
@export var movementFactorGround : float = 12;
@export var movementMomentumDampeningGround : float = 16;
var movementMomentum : Vector3 = Vector3.ZERO;
# Ground.
@export var movementSpeed : float = 3.0;
# Gravity.
@export var movementUseGravity : bool = true;
@export var movementGravityAcceleration : float = -9.8;
var movementGravity : float = 0;

@export_category("Combat")
# Health.
@export var combatInvincible : bool = false;
@export var combatTotalHealth : int = 1;
@export var combatContactDamage : int = 1;
# Knockback.
@export var combatUseKnockback : bool = true;
@export var combatKnockbackDampening : float = 6;
var combatKnockback : Vector3 = Vector3.ZERO;

@export_category("Animation")
@export var animationOrigin : Node3D;
@export var animationPlayer : AnimationPlayer;

@export_category("EntityType")
@export var entityType : EntityType = EntityType.EntityType_None; 
@export var entityTarget : Node3D;

enum EntityType {
	EntityType_None,
	
	EntityType_Mushroom,	
};

func _physics_process(delta):
	# Accumulate total movement.
	var totalMovement : Vector3 = Vector3.ZERO;
	
	# Handle gravity.
	if (movementUseGravity): 
		handleGravity(delta);
		totalMovement += verticalMovement;
	# Handle knockback;
	if (combatUseKnockback): 
		handleKnockback(delta);
		totalMovement += combatKnockback;
		
	# Handle momentum.
	handleMomentum(delta);
	totalMovement += movementMomentum;
	
	# Handle entity brain.
	if (entityTarget):
		var targetDistance : float = global_position.distance_to(entityTarget.global_position);
		match (entityType):
			EntityType.EntityType_Mushroom:
				if (targetDistance < 12.0):
					horizontalMovement = global_position.direction_to(entityTarget.global_position) * movementSpeed;
					horizontalMovement.y = 0;
				else:
					horizontalMovement = Vector3.ZERO;
					
				if (combatTotalHealth <= 0):
					# Sit.
					playAnimation("Mushroom_Fell");
					horizontalMovement = Vector3.ZERO;
				elif (iFrameTimeRemaining > 0):
					# Ouchies.
					playAnimation("Mushroom_Fell");					
					horizontalMovement = Vector3.ZERO;
				elif (movementMomentum.length_squared() > 0):
					# Running.
					playAnimation("Mushroom_Running");
				else:
					# Idle.
					playAnimation("Mushroom_Idle");
	
	if (animationOrigin && movementMomentum.length_squared() > 0): 
		animationOrigin.look_at(animationOrigin.global_position - movementMomentum);
	
	# Move!
	if (movementUseMovement && combatTotalHealth > 0):
		velocity = totalMovement;	
		move_and_slide();
		
	# ??
	handleIFrames(delta);
	
################################################################################

func _onDamageHit(damage : int): 
	if (combatInvincible || iFrameTimeRemaining > 0.0): return;
	
	# Reduce health.
	combatTotalHealth -= damage;
	iFrameTimeRemaining = iFrameTimeOnHit;
	
	# Destroy.
	if (combatTotalHealth <= 0 && iFrameTimeRemaining <= 0.0):
		queue_free();

################################################################################

@export_category("iFrames")
@export var iFrameMesh : MeshInstance3D;
var iFrameShader : Shader = preload("res://Shaders/WorldShaderIFrame.gdshader");
@export var iFrameTimeOnHit : float = 1.0;
var iFrameTimeRemaining : float = 0.0;
var baseShader : Shader;

func handleIFrames(delta):
	if (iFrameTimeRemaining > 0.0):
		iFrameTimeRemaining -= delta;
	if (iFrameTimeRemaining <= 0.0 && combatTotalHealth <= 0):
		queue_free();
		return;
	
	if (!iFrameMesh || !iFrameShader): return;
	# Get material.
	var mat : ShaderMaterial = iFrameMesh.material_override as ShaderMaterial;
	if (!mat): return;
	
	if (iFrameTimeRemaining > 0.0):
		iFrameTimeRemaining -= delta;
		if (mat.shader != iFrameShader):
			baseShader = mat.shader;
			mat.shader = iFrameShader;
	elif (mat.shader == iFrameShader):
			mat.shader = baseShader;	
			

################################################################################

var horizontalMovement : Vector3 = Vector3.ZERO;
func handleMomentum(delta):
	# Update momentum.
	if (horizontalMovement.length_squared() > 0):
		# Maintain.
		movementMomentum = movementMomentum.move_toward(horizontalMovement, movementFactorGround  * delta);
	else:
		# Dampen.
		movementMomentum = movementMomentum.move_toward(Vector3.ZERO, movementMomentumDampeningGround * delta)

################################################################################

var verticalMovement : Vector3;
func handleGravity(delta):
	# Update gravity.	
	var gravityFactor : float = movementGravityAcceleration * 0.5 * delta;
	
	# Handle floor factor.
	if (is_on_floor()): 
		movementGravity = 0.0;
		gravityFactor = 0.0;
	
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
	
################################################################################

var lastAnimation : String = "";
func playAnimation(animation : String):
	# Safety first.
	if (!animationPlayer || !animationPlayer.has_animation(animation)): 
		return;	
	
	# Set new animation if not already set.
	if (lastAnimation == animation): return;
	animationPlayer.set_current_animation(animation);
	lastAnimation = animation;
		
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
	animationPlayer.seek(percentage * animationPlayer.current_animation_length * 0.98);
	
func setAnimationSpeed(percentage : float):
	# Safety first.
	if (!animationPlayer): 
		return;
		
	# Set speed scale.
	animationPlayer.speed_scale = percentage;

################################################################################
