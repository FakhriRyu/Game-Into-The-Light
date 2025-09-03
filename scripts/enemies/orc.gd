extends CharacterBody2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
var current_state = State.PATROL

var speed = 30
var patrol_range = 30
var start_position
var direction = 1
var health = 50
var target: CharacterBody2D = null
var attack_damage = 10
var last_direction = 1  # Tambahkan variabel untuk menyimpan arah terakhir
var direction_threshold = 5  # Threshold minimum untuk perubahan arah
var _death_timer_started := false

func _ready():
	start_position = global_position
	if not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			state_idle()
		State.PATROL:
			state_patrol(delta)
		State.CHASE:
			state_chase(delta)
		State.ATTACK:
			state_attack(delta)
		State.HURT:
			state_hurt(delta)
		State.DEAD:
			state_dead()

	if not is_on_floor():
		velocity += get_gravity() * delta

func state_idle():
	anim_player.play("idle")

func state_patrol(_delta):
	anim_player.play("walk")
	velocity.x = direction * speed
	sprite.flip_h = direction < 0
	move_and_slide()
	
	# balik arah kalau sudah melewati patrol_range
	if abs(global_position.x - start_position.x) > patrol_range:
		direction *= -1
	
	# kalau HP habis → mati
	if health <= 0:
		change_state(State.DEAD)

func state_chase(_delta):
	if target == null:
		change_state(State.PATROL)
		return
	
	anim_player.play("walk")
	var dir = sign(target.global_position.x - global_position.x)
	var chase_speed = speed * 1.7
	
	# Hanya ubah arah jika perbedaan posisi cukup signifikan
	if abs(target.global_position.x - global_position.x) > direction_threshold:
		velocity.x = dir * chase_speed
		# Hanya ubah flip_h jika arah berubah
		if dir != 0 and dir != last_direction:
			sprite.flip_h = dir < 0
			last_direction = dir
	else:
		# Jika player di atas orc, hentikan gerakan horizontal
		velocity.x = 0
	
	move_and_slide()
	
	if health <= 0:
		change_state(State.DEAD)

func state_attack(_delta):
	if target == null or (target.has_method("is_dead") and target.is_dead):
		$AttackTimer.stop()
		change_state(State.IDLE)
		return

	velocity.x = 0
	anim_player.play("attack")

	# Hanya ubah flip_h jika perbedaan posisi cukup signifikan
	var dir = sign(target.global_position.x - global_position.x)
	if abs(target.global_position.x - global_position.x) > direction_threshold and dir != 0:
		sprite.flip_h = dir < 0

func state_hurt(_delta):
	velocity.x = 0
	anim_player.play("hurt")
	move_and_slide()

func state_dead():
	velocity = Vector2.ZERO
	if not _death_timer_started:
		_death_timer_started = true
		anim_player.play("dead")
		await get_tree().create_timer(3.0).timeout
		queue_free()

func change_state(new_state):
	if current_state == State.DEAD:
		return
	# No-op if same state
	if new_state == current_state:
		return
	# When dying, stop attacks and clear target
	if new_state == State.DEAD:
		if $AttackTimer.is_stopped() == false:
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


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):   # pastikan Player dimasukkan ke group "player"
		target = body
		change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		change_state(State.IDLE)

func _on_melee_area_body_entered(body: Node2D) -> void:
	if body == target:
		change_state(State.ATTACK)
		$AttackTimer.start()

func _on_melee_area_body_exited(body: Node2D) -> void:
	if body == target:
		$AttackTimer.stop()
		change_state(State.CHASE)

func _on_attack_timer_timeout() -> void:
	if current_state != State.ATTACK or target == null:
		return
	
	# Pastikan player belum mati
	if target.has_method("is_dead") and target.is_dead:
		$AttackTimer.stop()
		change_state(State.PATROL)
		return

	if target.has_method("take_damage"):
		target.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		change_state(State.DEAD)
		return
	$AttackTimer.stop()
	change_state(State.HURT)
