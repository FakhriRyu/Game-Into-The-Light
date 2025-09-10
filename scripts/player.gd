extends CharacterBody2D

signal health_changed(current: int, max: int)
signal died
signal respawned

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
var _attack_area_base_pos: Vector2
var _attack_shape_base_pos: Vector2

# --- Movement tunables ---
@export var SPEED: float = 90.0
@export var JUMP_VELOCITY: float = -220.0
@export var ACCEL: float = 1200.0
@export var FRICTION: float = 1400.0

# --- Jump feel (coyote & buffer & variable jump) ---
@export var COYOTE_TIME: float = 0.12
@export var JUMP_BUFFER: float = 0.12
@export var EARLY_RELEASE_GRAVITY_MULT: float = 2.0

# --- Health / combat ---
@export var MAX_HEALTH: int = 30
@export var I_FRAMES: float = 0.6
@export var KNOCKBACK: Vector2 = Vector2(80, -120)

#--- Attack ---
@export var ATTACKING: bool = false
@export var ATTACK_DAMAGE: int = 10
var _already_hit: Dictionary = {}

var health: int
var is_dead := false
var spawn_point: Vector2
var _invul_until := 0.0

# cache gravity dari Project Settings (Godot 4)
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

# timers internal
var _coyote_left := 0.0
var _jump_buf_left := 0.0
var _jump_held := false

func _ready() -> void:
	add_to_group("player")
	spawn_point = global_position
	health = MAX_HEALTH
	emit_signal("health_changed", health, MAX_HEALTH)

	# cache base offset of attack area and sync to current facing
	_attack_area_base_pos = attack_area.position
	_attack_shape_base_pos = attack_shape.position
	_update_attack_area_side()

	# Reset attack state when animation ends
	if not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)

	# AttackArea initial setup
	attack_area.monitoring = false
	attack_area.set_deferred("monitorable", false)
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	if not attack_area.area_entered.is_connected(_on_attack_area_area_entered):
		attack_area.area_entered.connect(_on_attack_area_area_entered)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		attack()

func _physics_process(delta: float) -> void:
	# --- Timers untuk coyote & jump buffer ---
	if is_on_floor():
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = max(0.0, _coyote_left - delta)

	_jump_buf_left = max(0.0, _jump_buf_left - delta)

	# --- Input & Movement Lock saat ATTACKING ---
	if not ATTACKING:
		var dir := Input.get_axis("move_left", "move_right")
		_jump_logic(delta)
		# --- Horizontal movement dengan accel/friction ---
		if dir != 0:
			velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	else:
		# Kunci gerak horizontal saat menyerang
		velocity.x = 0

	# --- Gravity ---
	if not is_on_floor():
		# variable jump: saat tombol dilepas, tarik lebih cepat turun
		var g := gravity
		if velocity.y < 0 and not _jump_held:
			g *= EARLY_RELEASE_GRAVITY_MULT
		velocity.y += g * delta

	move_and_slide()
	_update_animation()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		if ATTACKING:
			return
		_jump_buf_left = JUMP_BUFFER
		_jump_held = true
	elif event.is_action_released("jump"):
		_jump_held = false

func _jump_logic(_delta: float) -> void:
	# Boleh lompat jika masih punya coyote time dan ada input jump (buffered)
	if _jump_buf_left > 0.0 and _coyote_left > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buf_left = 0.0
		_coyote_left = 0.0

func attack() -> void:
	ATTACKING = true

	anim_player.play("attack")
	# Pastikan hitbox serangan berada di sisi yang benar saat mulai menyerang
	_update_attack_area_side()

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		ATTACKING = false
		attack_hitbox_off()

func attack_hitbox_on() -> void:
	_already_hit.clear()
	attack_area.monitoring = true
	attack_area.set_deferred("monitorable", true)

func attack_hitbox_off() -> void:
	attack_area.monitoring = false
	attack_area.set_deferred("monitorable", false)
	_already_hit.clear()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not ATTACKING:
		return
	if body == self:
		return
	if not body.is_in_group("enemy"):
		return
	var id: int = body.get_instance_id()
	if _already_hit.has(id):
		return
	_already_hit[id] = true
	if body.has_method("take_damage"):
		body.take_damage(ATTACK_DAMAGE)

func _on_attack_area_area_entered(area: Area2D) -> void:
	if not ATTACKING:
		return
	var name_lower := String(area.name).to_lower()
	if name_lower.find("hurt") == -1:
		return
	var target: Node = area.get_parent()
	if target == null or target == self:
		return
	var tid: int = target.get_instance_id()
	if _already_hit.has(tid):
		return
	_already_hit[tid] = true
	if target.has_method("take_damage"):
		target.take_damage(ATTACK_DAMAGE)

func _update_animation() -> void:
	if not ATTACKING:
		if is_dead:
			anim_player.play("dead")
			return

		if not is_on_floor():
			if velocity.y < 0:
				anim_player.play("jump")
			else:
				anim_player.play("fall")
		else:
			if abs(velocity.x) > 1.0:
				anim_player.play("run")
			else:
				anim_player.play("idle")

	# Flip arah
	if abs(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0
		_update_attack_area_side()

func _update_attack_area_side() -> void:
	# Mirror the collision shape position instead of the Area2D node,
	# because the shape carries the actual offset used for collisions.
	var pos := _attack_shape_base_pos
	pos.x = abs(pos.x) * (-1 if sprite.flip_h else 1)
	attack_shape.position = pos

# ---------------- Combat / Health ----------------

func take_damage(amount: int, from_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	if Time.get_unix_time_from_system() < _invul_until:
		return

	health = max(0, health - amount)
	emit_signal("health_changed", health, MAX_HEALTH)
	print("Player kena damage: ", amount, " | HP sisa: ", health)

	# knockback opsional (arah dari serangan; kalau nol, pakai arah hadap)
	var kb := KNOCKBACK
	if from_dir != Vector2.ZERO:
		kb.x = abs(kb.x) * sign(-from_dir.x)
	else:
		kb.x = abs(kb.x) * (-1 if sprite.flip_h else 1)

	velocity += kb

	_invul_until = Time.get_unix_time_from_system() + I_FRAMES
	_blink_i_frames(I_FRAMES)

	if health <= 0:
		_die()

func _blink_i_frames(duration: float) -> void:
	# efek visual simpel: kedip selama i-frames (non-blocking)
	var tween := create_tween()
	tween.set_loops(int(duration / 0.1))
	tween.tween_property(sprite, "modulate:a", 0.2, 0.05)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

func _die() -> void:
	is_dead = true
	print("Player mati!")
	emit_signal("died")
	anim_player.play("dead")
	set_physics_process(false)
	# respawn setelah 2 detik
	_respawn_after_delay(2.0)

func _respawn_after_delay(seconds: float) -> void:
	# versi 'await' yang ringkas
	await get_tree().create_timer(seconds).timeout
	_respawn()

func _respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	is_dead = false
	_invul_until = Time.get_unix_time_from_system() + 0.5  # aman sebentar
	set_physics_process(true)
	anim_player.play("idle")
	emit_signal("health_changed", health, MAX_HEALTH)
	emit_signal("respawned")
	print("Player respawn di: ", spawn_point)

# Util, kalau mau pindah checkpoint dari luar
func set_spawn(point: Vector2) -> void:
	spawn_point = point
