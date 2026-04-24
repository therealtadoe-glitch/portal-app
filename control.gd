extends Control



func _on_info_button_pressed() -> void:
	ToastManager.show_info("Here is a useful info toast.")


func _on_success_button_pressed() -> void:
	ToastManager.show_success("Here is a useful success toast.")


func _on_warning_button_pressed() -> void:
	ToastManager.show_warning("Here is a useful warning toast.")


func _on_error_button_pressed() -> void:
	ToastManager.show_error("Here is a useful error toast")
