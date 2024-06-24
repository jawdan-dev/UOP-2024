extends Area3D

@export var bobPeriod : float = 5.0;
@export var bobHeight : float = 0.125;

@export_range(0, 1) var collectedScale : float = 0.0;
@export_range(1, 8) var collectedHeight : float = 4.0;
@export_range(1, 16) var collectedSpeed : float = 6.0;
@export var collectionTime : float = 0.8;

@onready var bobTarget : Node3D = $Coin;
@onready var startPosition : Vector3 = bobTarget.global_position;
@onready var t : float = randf() * bobPeriod;
@onready var invPeriod : float = TAU / bobPeriod;

func _ready(): 
	const scaleRange = 0.2;
	bobTarget.scale *= Vector3.ONE * randf_range(1.0 - scaleRange, 1.0 + scaleRange);

var collectionProgress : float = 0.0;
func _process(delta):
	# Update t.
	t += delta;
	
	# onCollect.
	if (collected):
		# Handle collection progress update.
		collectionProgress += delta / collectionTime;
		if (collectionProgress >= 1.0):
			queue_free();
			return;
			
		# Behave.
		bobTarget.global_position = startPosition + Vector3(0, (sin(t * invPeriod) * bobHeight) + lerpf(0.0, collectedHeight, collectionProgress), 0);
		bobTarget.rotation.y = t * invPeriod * 0.5 * lerpf(1.0, collectedSpeed, collectionProgress);
		bobTarget.scale = Vector3.ONE * lerpf(1, collectedScale, collectionProgress);
		return;
		
	# Normal behaviour.
	bobTarget.global_position = startPosition + Vector3(0, sin(t * invPeriod) * bobHeight, 0);
	bobTarget.rotation.y = t * invPeriod * 0.5;

var collected : bool = false;
func _onPlayerEnter(body : Node3D):
	collected = true;
