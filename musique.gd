extends FmodEventEmitter3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			print("-> sonChill")
			set_parameter("etatMusique", "sonChill")
		elif event.physical_keycode == KEY_2:
			print("-> sonTransition")
			set_parameter("etatMusique", "sonTransition")
		elif event.physical_keycode == KEY_3:
			print("-> sonPeur")
			set_parameter("etatMusique", "sonPeur")
