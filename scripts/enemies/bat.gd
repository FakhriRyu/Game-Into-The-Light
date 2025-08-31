extends CharacterBody2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state = State.PATROL

var speed = 40
var patrol_range = 20
var start_position: Vector2
var direction = 1
var health = 30
var target: CharacterBody2D = null
var attack_damage = 5

func _ready():
	start_position = global_position

func _physics_process(delta):
	match current_state:
		State.PATROL:
			state_patrol(delta)
		State.CHASE:
			state_chase(delta)
		State.ATTACK:
			state_attack()
		State.DEAD:
			state_dead()

func state_patrol(_delta):
	anim_player.play("fly")
	
	# Simple horizontal patrol with minimal vertical movement
	velocity.x = direction * speed * 0.3  # Much slower for smoother movement
	velocity.y = sin(Time.get_time_dict_from_system()["second"] * 0.5) * 3  # Very small vertical movement
	
	# Add buffer zone to prevent constant direction changes
	var distance_from_start = abs(global_position.x - start_position.x)
	if distance_from_start > patrol_range:
		# Move back towards center before changing direction
		if direction > 0:  # Moving right
			velocity.x = -speed * 0.3  # Move left
		else:  # Moving left
			velocity.x = speed * 0.3   # Move right
		
		# Only change direction when back near center
		if distance_from_start < patrol_range * 0.3:
			direction *= -1
			sprite.flip_h = direction < 0
			print("Bat: Direction changed to ", direction)
	
	move_and_slide()

	if health <= 0:
		change_state(State.DEAD)

func state_chase(_delta):
	if target == null:
		change_state(State.PATROL)
		return

	anim_player.play("fly")
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * speed * 1.5
	
	# Only flip sprite when direction changes significantly
	var new_direction = sign(velocity.x)
	if new_direction != 0 and new_direction != direction:
		direction = new_direction
		sprite.flip_h = direction < 0
	
	move_and_slide()

	if health <= 0:
		change_state(State.DEAD)

func state_attack():
	if target == null or (target.has_method("is_dead") and target.is_dead):
		$AttackTimer.stop()
		change_state(State.PATROL)
		return

	anim_player.play("attack")
	velocity = Vector2.ZERO

func state_dead():
	anim_player.play("dead")
	velocity = Vector2.ZERO
	queue_free()

func change_state(new_state):
	print("Bat: State changed from ", State.keys()[current_state], " to ", State.keys()[new_state])
	current_state = new_state

# --- SIGNALS ---
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		change_state(State.PATROL)

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body == target:
		change_state(State.ATTACK)
		$AttackTimer.start()

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body == target:
		$AttackTimer.stop()
		change_state(State.CHASE)

func _on_attack_timer_timeout() -> void:
	if current_state != State.ATTACK or target == null:
		return

	if target.has_method("is_dead") and target.is_dead:
		$AttackTimer.stop()
		change_state(State.PATROL)
		return

	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
