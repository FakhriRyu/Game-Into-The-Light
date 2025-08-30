extends CharacterBody2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }
var current_state = State.PATROL

var speed = 30
var patrol_range = 50
var start_position
var direction = 1
var health = 50
var target: CharacterBody2D = null
var attack_damage = 10

func _ready():
	start_position = global_position

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
		State.DEAD:
			state_dead()

	if not is_on_floor():
		velocity += get_gravity() * delta

func state_idle():
	anim_player.play("idle")
	# contoh: langsung pindah ke patrol
	change_state(State.PATROL)

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
	var chase_speed = speed * 1.5
	velocity.x = dir * chase_speed
	sprite.flip_h = dir < 0
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

	var dir = sign(target.global_position.x - global_position.x)
	sprite.flip_h = dir < 0


func state_dead():
	velocity = Vector2.ZERO
	anim_player.play("dead")

func change_state(new_state):
	current_state = new_state


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):   # pastikan Player dimasukkan ke group "player"
		target = body
		change_state(State.CHASE)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		change_state(State.PATROL)

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
