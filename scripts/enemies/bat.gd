extends CharacterBody2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
var current_state = State.PATROL

var speed = 40
var patrol_range = 20
var start_position: Vector2
var direction = 1
var health = 30
var target: CharacterBody2D = null
var attack_damage = 5
var flip_h = false
var _death_timer_started := false

func _ready():
	start_position = global_position
	add_to_group("enemy")
	if not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			state_idle(delta)
		State.PATROL:
			state_patrol(delta)
		State.CHASE:
			state_chase(delta)
		State.ATTACK:
			state_attack()
		State.HURT:
			state_hurt(delta)
		State.DEAD:
			state_dead()

func state_idle(_delta):
	anim_player.play("fly")

func state_patrol(_delta):
	anim_player.play("fly")
	
	# Simple horizontal patrol with minimal vertical movement
	velocity.x = direction * speed * 1.2  # Much slower for smoother movement
	velocity.y = sin(Time.get_time_dict_from_system()["second"] * 0.5) * 3  # Very small vertical movement
	
	# Add buffer zone to prevent constant direction changes
	var distance_from_start = abs(global_position.x - start_position.x)
	if distance_from_start > patrol_range:
		# Move back towards center before changing direction
		if direction > 0:  # Moving right
			velocity.x = -speed * 1.2  # Move left
		else:  # Moving left
			velocity.x = speed * 1.2   # Move right
		
		# Only change direction when back near center
		if distance_from_start < patrol_range * 1.2:
			direction *= -1
			sprite.flip_h = direction < 0
	
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

func state_hurt(_delta):
	velocity = Vector2.ZERO
	anim_player.play("hurt")
	move_and_slide()

func state_dead():
	velocity = Vector2.ZERO
	if not _death_timer_started:
		_death_timer_started = true
		if not $AttackTimer.is_stopped():
			$AttackTimer.stop()
		target = null
		anim_player.play("dead")
		await get_tree().create_timer(1.0).timeout
		queue_free()

func change_state(new_state):
	if current_state == State.DEAD:
		return
	if new_state == current_state:
		return
	if new_state == State.DEAD:
		if not $AttackTimer.is_stopped():
			$AttackTimer.stop()
		target = null
	current_state = new_state

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "hurt" and current_state == State.HURT:
		if health <= 0:
			change_state(State.DEAD)
			return
		if target != null:
			change_state(State.CHASE)
		else:
			change_state(State.PATROL)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		change_state(State.DEAD)
		return
	$AttackTimer.stop()
	change_state(State.HURT)

# --- SIGNALS ---
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		change_state(State.IDLE)

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
