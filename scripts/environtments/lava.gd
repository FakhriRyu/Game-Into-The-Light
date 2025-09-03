extends AnimatableBody2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("_die"):
			body._die()
		elif body.has_method("take_damage"):
			body.take_damage(999999)
