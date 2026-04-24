@tool
extends CanvasLayer

var max_visible: int = 5
var newest_on_top: bool = true
var toast_width: float = 360.0
var top_margin: float = 24.0
var right_margin: float = 24.0
var spacing: float = 12.0

var enter_duration: float = 0.22
var exit_duration: float = 0.18
var move_duration: float = 0.18
var slide_distance: float = 48.0
var use_scale_pop: bool = true

var toasts: Array[Toast] = []
var tween: Tween

var _root: Control
var _host: Control
var _toast_tweens: Dictionary = {}


func _ready() -> void:
	_ensure_ui()

	var viewport: Viewport = get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	_reflow_toasts(false)

func _exit_tree() -> void:
	_kill_all_tweens()

	var viewport: Viewport = get_viewport()
	if viewport and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)

func _ensure_ui() -> void:
	_root = get_node_or_null("Root") as Control
	if _root == null:
		_root = Control.new()
		_root.name = "Root"
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_root)

	_host = _root.get_node_or_null("ToastHost") as Control
	if _host == null:
		_host = Control.new()
		_host.name = "ToastHost"
		_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.add_child(_host)

func show_toast(message: String, type: Toast.Type = Toast.Type.SUCCESS, duration: float = 4.0,) -> Toast:
	_ensure_ui()

	var toast: Toast = Toast.new()
	if toast == null:
		push_error("ToastManager: toast display not loaded correctly.")
		return null

	toast.type = type
	toast.text = message
	toast.timeout_duration = duration
	toast.start_timeout()

	toast.mouse_filter = Control.MOUSE_FILTER_STOP
	toast.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast.position = Vector2.ZERO
	toast.scale = Vector2.ONE
	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)

	_host.add_child(toast)
	_prepare_toast_size(toast)

	if newest_on_top:
		toasts.push_front(toast)
	else:
		toasts.append(toast)

	toast.timed_out.connect(_on_toast_timed_out.bind(toast))

	_enforce_max_visible(toast)
	_animate_in(toast)
	_reflow_toasts(true, toast)

	return toast

func show_info(message: String, duration: float = 4.0) -> Toast:
	return show_toast(message, Toast.Type.INFO, duration)

func show_success(message: String, duration: float = 4.0) -> Toast:
	return show_toast(message, Toast.Type.SUCCESS, duration)

func show_warning(message: String, duration: float = 4.0) -> Toast:
	return show_toast(message, Toast.Type.WARNING, duration)

func show_error(message: String, duration: float = 4.0) -> Toast:
	return show_toast(message, Toast.Type.ERROR, duration)

func dismiss_toast(toast: Toast, immediate: bool = false) -> void:
	if toast == null or not is_instance_valid(toast):
		return

	if not toasts.has(toast):
		return

	if _is_toast_closing(toast):
		return

	_set_toast_closing(toast, true)

	toasts.erase(toast)
	_kill_toast_tween(toast)

	if immediate:
		if is_instance_valid(toast):
			toast.queue_free()
		_reflow_toasts(true)
		return

	var exit_tween: Tween = create_tween()
	_track_tween(toast, exit_tween)

	exit_tween.set_parallel(true)
	exit_tween.set_trans(Tween.TRANS_CUBIC)
	exit_tween.set_ease(Tween.EASE_IN)

	exit_tween.tween_property(
		toast,
		"position",
		toast.position + Vector2(slide_distance, 0.0),
		exit_duration
	)
	exit_tween.tween_property(toast, "modulate:a", 0.0, exit_duration)

	if use_scale_pop:
		exit_tween.tween_property(toast, "scale", Vector2(0.96, 0.96), exit_duration)

	exit_tween.finished.connect(_on_toast_exit_finished.bind(toast), CONNECT_ONE_SHOT)

	_reflow_toasts(true)

func clear_all(immediate: bool = false) -> void:
	var active_toasts: Array[Toast] = toasts.duplicate()
	for toast: Toast in active_toasts:
		dismiss_toast(toast, immediate)

func _prepare_toast_size(toast: Toast) -> void:
	if toast_width > 0.0:
		toast.custom_minimum_size.x = toast_width
		toast.size.x = toast_width

func _animate_in(toast: Toast) -> void:
	if toast == null or not is_instance_valid(toast):
		return

	_prepare_toast_size(toast)

	var target: Vector2 = _get_toast_target_position(toast)
	toast.position = Vector2(get_viewport().size.x + slide_distance, target.y)

	if use_scale_pop:
		toast.scale = Vector2(0.96, 0.96)

	_kill_toast_tween(toast)

	var enter_tween: Tween = create_tween()
	_track_tween(toast, enter_tween)

	enter_tween.set_parallel(true)
	enter_tween.set_trans(Tween.TRANS_CUBIC)
	enter_tween.set_ease(Tween.EASE_OUT)

	enter_tween.tween_property(toast, "position", target, enter_duration)
	enter_tween.tween_property(toast, "modulate:a", 1.0, enter_duration - 0.01)

	if use_scale_pop:
		enter_tween.tween_property(toast, "scale", Vector2.ONE, enter_duration)

func _reflow_toasts(animated: bool, appearing_toast: Toast = null) -> void:
	_prune_invalid_toasts()

	for toast: Toast in toasts:
		if toast == null or not is_instance_valid(toast):
			continue

		if toast == appearing_toast:
			continue

		_prepare_toast_size(toast)

		var target: Vector2 = _get_toast_target_position(toast)

		if animated:
			_kill_toast_tween(toast)

			var move_tween: Tween = create_tween()
			_track_tween(toast, move_tween)
			move_tween.set_trans(Tween.TRANS_CUBIC)
			move_tween.set_ease(Tween.EASE_OUT)
			move_tween.tween_property(toast, "position", target, move_duration)
		else:
			toast.position = target

func _get_toast_target_position(target_toast: Toast) -> Vector2:
	var viewport_size: Vector2 = get_viewport().size
	var y: float = top_margin

	for toast: Toast in toasts:
		if toast == null or not is_instance_valid(toast):
			continue

		_prepare_toast_size(toast)

		var toast_size: Vector2 = _get_toast_size(toast)
		var x: float = viewport_size.x - right_margin - toast_size.x

		if toast == target_toast:
			return Vector2(x, y)

		y += toast_size.y + spacing

	return Vector2(viewport_size.x - right_margin, y)

func _get_toast_size(toast: Toast) -> Vector2:
	var min_size: Vector2 = toast.get_combined_minimum_size()
	var width: float = toast.size.x
	var height: float = toast.size.y

	if toast_width > 0.0:
		width = toast_width
	else:
		width = maxf(width, min_size.x)

	height = maxf(height, min_size.y)

	return Vector2(width, height)

func _enforce_max_visible(new_toast: Toast) -> void:
	if toasts.size() <= max_visible:
		return

	var oldest: Toast = null

	if newest_on_top:
		oldest = toasts[toasts.size() - 1]
	else:
		oldest = toasts[0]

	if oldest != null and oldest != new_toast:
		dismiss_toast(oldest, false)

func _prune_invalid_toasts() -> void:
	var valid_toasts: Array[Toast] = []

	for toast: Toast in toasts:
		if toast != null and is_instance_valid(toast):
			valid_toasts.append(toast)

	toasts = valid_toasts

func _track_tween(toast: Toast, new_tween: Tween) -> void:
	var key: int = toast.get_instance_id()
	_toast_tweens[key] = new_tween

func _kill_toast_tween(toast: Toast) -> void:
	var key: int = toast.get_instance_id()
	if not _toast_tweens.has(key):
		return

	var active_tween: Tween = _toast_tweens[key] as Tween
	if active_tween != null:
		active_tween.kill()

	_toast_tweens.erase(key)

func _kill_all_tweens() -> void:
	for value in _toast_tweens.values():
		var active_tween: Tween = value as Tween
		if active_tween != null:
			active_tween.kill()

	_toast_tweens.clear()

func _is_toast_closing(toast: Toast) -> bool:
	if toast == null or not is_instance_valid(toast):
		return false

	if not toast.has_meta("closing"):
		return false

	return bool(toast.get_meta("closing"))

func _set_toast_closing(toast: Toast, value: bool) -> void:
	if toast == null or not is_instance_valid(toast):
		return

	toast.set_meta("closing", value)

func _on_toast_close_pressed(toast: Toast) -> void:
	dismiss_toast(toast, false)

func _on_toast_timed_out(toast: Toast) -> void:
	if toast == null or not is_instance_valid(toast):
		return

	dismiss_toast(toast, false)

func _on_toast_exit_finished(toast: Toast) -> void:
	if toast == null or not is_instance_valid(toast):
		return

	_kill_toast_tween(toast)
	toast.queue_free()

func _on_viewport_size_changed() -> void:
	_reflow_toasts(false)
