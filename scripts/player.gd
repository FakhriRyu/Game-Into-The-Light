extends CharacterBody2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

const SPEED = 80.0
const JUMP_VELOCITY = -220.0

# Tambahan: health
var health := 30
var is_dead := false

func _ready():
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	update_animation()

func update_animation():
	if velocity.x != 0:
		anim_player.play("run")
		sprite.flip_h = velocity.x < 0
	else:
		anim_player.play("idle")

	if velocity.y < 0:
		anim_player.play("jump")
	elif velocity.y > 0:
		anim_player.play("fall")

# --------- Tambahan Fungsi ---------
func take_damage(amount: int) -> void:
	if is_dead: 
		return
	health -= amount
	print("Player kena damage: ", amount, " | HP sisa: ", health)

	if health <= 0:
		die()

func die():
	print("Player mati!")
	anim_player.play("dead")
	set_physics_process(false)  # disable input dan physics sementara
