extends CharacterBody3D

@export_category("Movement Properties")
# Gravity.
@export var movementGravityAcceleration : float = -9.8;
var movementGravity : float = 0;

@export_category("Combat")
# Knockback.
@export var combatKnockbackDampening : float = 6;
var combatKnockback : Vector3 = Vector3.ZERO;

func _physics_process(delta):
	# Handle gravity.
	handleGravity(delta);
	# Handle knockback;
	handleKnockback(delta);
	
	# Get default total movement.
	var totalMovement : Vector3 = verticalMovement + combatKnockback;
	
	# Move!
	velocity = totalMovement;	
	move_and_slide();
	
################################################################################

func _onPlayerHit(body : Area3D):
	body.get_parent_node_3d().call("_onEntityHit", self);

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
