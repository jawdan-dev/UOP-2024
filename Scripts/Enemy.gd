extends CharacterBody3D

@export_category("Movement Properties")
# Movement.
@export var movementUseMovement : bool = true;
# Gravity.
@export var movementUseGravity : bool = true;
@export var movementGravityAcceleration : float = -9.8;
var movementGravity : float = 0;

@export_category("Combat")
# Health.
@export var combatInvincible : bool = false;
@export var combatTotalHealth : int = 1;
# Knockback.
@export var combatUseKnockback : bool = true;
@export var combatKnockbackDampening : float = 6;
var combatKnockback : Vector3 = Vector3.ZERO;

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
	
	# Move!
	if (movementUseMovement):
		velocity = totalMovement;	
		move_and_slide();
	
################################################################################

func _onPlayerHit(body : Area3D):
	body.get_parent_node_3d().call("_onEntityHit", self);
	
func _onDamageHit(damage : int): 
	if (combatInvincible): return;
	
	# Reduce health.
	combatTotalHealth -= damage;
	
	# TODO: Texture animation based on health?
	
	# Destroy.
	if (combatTotalHealth <= 0):
		queue_free();

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
