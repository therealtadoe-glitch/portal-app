@tool
class_name Toast
extends Container

signal close_requested ## [color=blue]Emitted[/color] whenever the [member close_button_icon] is pressed.
signal timed_out ## [color=blue]Emitted[/color] whenever the [member progress] value reaches 1.0 or "100%"


enum ProgressShrinkDirection {
	LEFT_TO_RIGHT,
	RIGHT_TO_LEFT
}

enum Type {
	INFO,
	SUCCESS,
	WARNING,
	ERROR
}

const ICONS: Dictionary = {
	"info": preload("res://assets/icons/toast_icons/info.svg"),
	"success": preload("res://assets/icons/toast_icons/success.svg"),
	"warning": preload("res://assets/icons/toast_icons/warning.svg"),
	"error": preload("res://assets/icons/toast_icons/error.svg")
}


@export var type: Type = Type.SUCCESS:
	set(value):
		type = value
		set_type(type)
@export_multiline var text: String = "Wow so easy":
	set(value):
		text = value
		update_minimum_size()
		queue_redraw()


@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		horizontal_alignment = value
		update_minimum_size()
		queue_redraw()
@export var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER:
	set(value):
		vertical_alignment = value
		update_minimum_size()
		queue_redraw()
@export var icon_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER:
	set(value):
		icon_vertical_alignment = value
		queue_redraw()


@export_group("Text Wrapping")
@export var text_wrap_enabled: bool = true:
	set(value):
		text_wrap_enabled = value
		update_minimum_size()
		queue_redraw()
@export_range(0, 4096, 1) var text_wrap_width: int = 280:
	set(value):
		text_wrap_width = value
		update_minimum_size()
		queue_redraw()
@export_range(0, 64, 1) var max_visible_text_lines: int = 1:
	set(value):
		max_visible_text_lines = value
		update_minimum_size()
		queue_redraw()
@export var ellipsize_clipped_text: bool = true:
	set(value):
		ellipsize_clipped_text = value
		update_minimum_size()
		queue_redraw()
@export var clipping_ellipsis: String = "…":
	set(value):
		clipping_ellipsis = value
		update_minimum_size()
		queue_redraw()


@export_group("Timeout")
@export var auto_start_timeout: bool = true:
	set(value):
		auto_start_timeout = value
@export_range(0.1, 120.0, 0.1) var timeout_duration: float = 3.0:
	set(value):
		timeout_duration = value


@export_group("Close Button")
@export var close_button_visible: bool = true:
	set(value):
		close_button_visible = value
		update_minimum_size()
		queue_redraw()
@export_range(8, 64, 1) var close_button_size: int = 16:
	set(value):
		close_button_size = value
		update_minimum_size()
		queue_redraw()
@export_range(0, 32, 1) var close_button_margin: int = 9:
	set(value):
		close_button_margin = value
		update_minimum_size()
		queue_redraw()
@export_range(0, 32, 1) var close_button_spacing: int = 8:
	set(value):
		close_button_spacing = value
		update_minimum_size()
		queue_redraw()


@export_group("Progress Bar")
@export_range(0.0, 1.0, 0.001) var progress: float = 0.0:
	set(value):
		var previous_progress: float = progress
		progress = value
		_update_timed_out_state(previous_progress)
		queue_redraw()
@export var progress_color: Color = Color("55b938"):
	set(value):
		progress_color = value
		queue_redraw()


@export_group("Theme Overrides")
@export_subgroup("Colors")
@export var icon_color: Color = Color("55b938"):
	set(value):
		icon_color = value
		queue_redraw()
@export var text_color: Color = Color("000000"):
	set(value):
		text_color = value
		queue_redraw()


@export_subgroup("Constants")
@export_range(0, 256, 1) var icon_size: int = 24:
	set(value):
		icon_size = maxi(value, 0)
		update_minimum_size()
		queue_redraw()
@export_range(0, 64, 1) var icon_spacing: int = 8:
	set(value):
		icon_spacing = value
		update_minimum_size()
		queue_redraw()
@export_range(0, 64, 1) var line_spacing: int = 0:
	set(value):
		line_spacing = value
		update_minimum_size()
		queue_redraw()


@export_subgroup("Font")
@export var font: Font:
	set(value):
		if font == value:
			update_minimum_size()
			queue_redraw()
			return

		_unobserve_font()

		font = value

		_observe_current_font()
		update_minimum_size()
		queue_redraw()


@export_subgroup("Font Size")
@export_range(1, 128, 1) var font_size: int = 14:
	set(value):
		font_size = value
		update_minimum_size()
		queue_redraw()


@export_subgroup("Styles")
@export var stylebox: StyleBox:
	set(value):
		if stylebox == value:
			update_minimum_size()
			queue_redraw()
			return

		_unobserve_stylebox()

		stylebox = value

		_observe_current_stylebox()
		update_minimum_size()
		queue_redraw()


@export_group("")
@export_tool_button("Preview")
var c: Callable = func():
	start_timeout()


var _observed_stylebox: StyleBox = null
var _observed_font: Font = null
var _close_button_hovered: bool = false
var _close_button_pressed: bool = false
var _timed_out_emitted: bool = false
var _progress_tween: Tween = null
var _runtime_ready: bool = false


var progress_visible: bool = true:
	set(value):
		progress_visible = value
		update_minimum_size()
		queue_redraw()
var progress_background_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		progress_background_color = value
		queue_redraw()
var progress_shrink_direction: ProgressShrinkDirection = ProgressShrinkDirection.LEFT_TO_RIGHT:
	set(value):
		progress_shrink_direction = value
		queue_redraw()
var progress_clip_arc_segments: int = 12:
	set(value):
		progress_clip_arc_segments = value
		queue_redraw()
var progress_height: int = 5:
	set(value):
		progress_height = value
		update_minimum_size()
		queue_redraw()
var progress_reserve_content_space: bool = false:
	set(value):
		progress_reserve_content_space = value
		update_minimum_size()
		queue_redraw()

var close_button_icon_padding: int = 0:
	set(value):
		close_button_icon_padding = value
		queue_redraw()
var close_button_line_width: int = 2:
	set(value):
		close_button_line_width = value
		queue_redraw()
var close_button_icon_color: Color = Color(0.788, 0.788, 0.788, 1.0):
	set(value):
		close_button_icon_color = value
		queue_redraw()
var close_button_icon_hover_color: Color = Color(0.86, 0.86, 0.86, 1.0):
	set(value):
		close_button_icon_hover_color = value
		queue_redraw()
var close_button_icon_pressed_color: Color = Color(0.654, 0.654, 0.654, 1.0):
	set(value):
		close_button_icon_pressed_color = value
		queue_redraw()
var close_button_hover_background_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		close_button_hover_background_color = value
		queue_redraw()
var close_button_icon: Texture2D = preload("res://assets/icons/toast_icons/Close Icon.svg"):
	set(value):
		close_button_icon = value
		queue_redraw()


var icon: Texture2D:
	set(value):
		icon = value
		update_minimum_size()
		queue_redraw()




func _ready() -> void:
	custom_minimum_size.y = 64
	_runtime_ready = true

	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		mouse_filter = Control.MOUSE_FILTER_PASS

	set_type(type)
	set_default_stylebox()

	_observe_current_stylebox()
	_observe_current_font()
	update_minimum_size()
	queue_redraw()

	if auto_start_timeout:
		start_timeout()

func _exit_tree() -> void:
	stop_timeout()
	_unobserve_stylebox()
	_unobserve_font()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			_observe_current_stylebox()
			_observe_current_font()
			update_minimum_size()
			queue_redraw()

		NOTIFICATION_RESIZED:
			queue_redraw()

		NOTIFICATION_MOUSE_EXIT:
			if _close_button_hovered or _close_button_pressed:
				_close_button_hovered = false
				_close_button_pressed = false
				queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not close_button_visible:
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var was_hovered: bool = _close_button_hovered

		_close_button_hovered = get_close_button_rect().has_point(motion_event.position)

		if was_hovered != _close_button_hovered:
			queue_redraw()

		return

	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
			return

		var is_inside_close_button: bool = get_close_button_rect().has_point(mouse_button_event.position)

		if mouse_button_event.pressed:
			if is_inside_close_button:
				_close_button_pressed = true
				queue_redraw()
				accept_event()
		else:
			var was_pressed: bool = _close_button_pressed
			_close_button_pressed = false

			if was_pressed:
				queue_redraw()
				accept_event()

				if is_inside_close_button:
					close_requested.emit()

func _draw() -> void:
	var active_stylebox: StyleBox = _get_active_stylebox()

	if active_stylebox != null:
		draw_style_box(active_stylebox, Rect2(Vector2.ZERO, size))

	_draw_content_row()
	_draw_progress_bar()
	_draw_close_button()

func _get_minimum_size() -> Vector2:
	var row_size: Vector2 = get_content_row_size()

	var minimum_width: float = row_size.x
	minimum_width += _get_horizontal_stylebox_margins()
	minimum_width += _get_close_button_reserved_width()

	var minimum_height: float = row_size.y
	minimum_height += _get_vertical_stylebox_margins()
	minimum_height += _get_progress_reserved_height()

	return Vector2(
		ceilf(maxf(minimum_width, _get_close_button_minimum_width())),
		ceilf(maxf(minimum_height, _get_close_button_minimum_height()))
	)

func start_timeout() -> void:
	if not is_inside_tree():
		return

	stop_timeout()

	progress = 0.0
	reset_timed_out_state()

	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_LINEAR)
	_progress_tween.set_ease(Tween.EASE_IN_OUT)
	_progress_tween.finished.connect(_on_progress_tween_finished)
	_progress_tween.tween_property(self, "progress", 1.0, timeout_duration)

func stop_timeout() -> void:
	if _progress_tween != null:
		_progress_tween.kill()
		_progress_tween = null

func restart_timeout() -> void:
	start_timeout()

func reset_timeout() -> void:
	stop_timeout()
	progress = 0.0
	reset_timed_out_state()

func reset_timed_out_state() -> void:
	_timed_out_emitted = false

func is_timeout_running() -> bool:
	return _progress_tween != null and _progress_tween.is_valid()

func _on_progress_tween_finished() -> void:
	_progress_tween = null

func _update_timed_out_state(previous_progress: float) -> void:
	if progress < 1.0:
		_timed_out_emitted = false
		return

	if _timed_out_emitted:
		return

	if previous_progress >= 1.0:
		return

	_timed_out_emitted = true

	if _runtime_ready and is_inside_tree() and not Engine.is_editor_hint():
		timed_out.emit()

func swap_color(new_color: Color) -> void:
	if progress_color != new_color:
		progress_color = new_color
	if icon_color != new_color:
		icon_color = new_color

func swap_icon(new_icon: Texture2D) -> void:
	if icon != new_icon:
		icon = new_icon

func set_default_stylebox() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(4)
	sb.corner_detail = 20
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	
	stylebox = sb
	
	text_color = Color()

func set_type(new_type: Type) -> void:
	match new_type:
		Type.INFO:
			swap_icon(ICONS["info"])
			swap_color(Color("5296D5"))
		Type.SUCCESS:
			swap_icon(ICONS["success"])
			swap_color(Color("55B938"))
		Type.WARNING:
			swap_icon(ICONS["warning"])
			swap_color(Color("EAC645"))
		Type.ERROR:
			swap_icon(ICONS["error"])
			swap_color(Color("D65745"))

func get_content_row_size() -> Vector2:
	var icon_draw_size: Vector2 = get_icon_draw_size()
	var spacing: float = _get_active_icon_spacing()
	var text_width_limit: float = _get_minimum_text_wrap_width_limit()
	var text_size: Vector2 = get_text_render_size_for_width(text_width_limit)

	var row_width: float = icon_draw_size.x + spacing + text_size.x
	var row_height: float = maxf(icon_draw_size.y, text_size.y)

	return Vector2(row_width, row_height)

func get_content_row_size_for_width(available_width: float) -> Vector2:
	var icon_draw_size: Vector2 = get_icon_draw_size()
	var spacing: float = _get_active_icon_spacing()
	var available_text_width: float = maxf(0.0, available_width - icon_draw_size.x - spacing)
	var text_width_limit: float = _get_effective_text_wrap_width(available_text_width)
	var text_size: Vector2 = get_text_render_size_for_width(text_width_limit)

	var row_width: float = icon_draw_size.x + spacing + text_size.x
	var row_height: float = maxf(icon_draw_size.y, text_size.y)

	return Vector2(row_width, row_height)

func get_text_width() -> float:
	return get_text_render_size().x

func get_text_height() -> float:
	return get_text_render_size().y

func get_text_render_size() -> Vector2:
	return get_text_render_size_for_width(_get_minimum_text_wrap_width_limit())

func get_text_render_size_for_width(max_width: float) -> Vector2:
	if text.is_empty():
		return Vector2.ZERO

	var display_lines: PackedStringArray = _get_display_text_lines(max_width)
	return _get_text_lines_render_size(display_lines)

func _get_text_lines_render_size(lines: PackedStringArray) -> Vector2:
	if lines.is_empty():
		return Vector2.ZERO

	var active_font: Font = get_font()
	var max_width: float = 0.0
	var line_index: int = 0

	while line_index < lines.size():
		var line: String = lines[line_index]
		var line_width: float = active_font.get_string_size(
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x

		max_width = maxf(max_width, line_width)
		line_index += 1

	var line_height: float = active_font.get_height(font_size)
	var total_height: float = line_height * float(lines.size())
	total_height += float(line_spacing * maxi(lines.size() - 1, 0))

	return Vector2(max_width, total_height)

func get_icon_draw_size() -> Vector2:
	if icon == null:
		return Vector2.ZERO

	if icon_size <= 0:
		return Vector2.ZERO

	var size_value: float = float(icon_size)
	return Vector2(size_value, size_value)

func _draw_content_row() -> void:
	var content_rect: Rect2 = _get_content_rect()
	var row_size: Vector2 = get_content_row_size_for_width(content_rect.size.x)

	if row_size == Vector2.ZERO:
		return

	var row_position: Vector2 = _get_aligned_row_position(content_rect, row_size)
	var icon_draw_size: Vector2 = get_icon_draw_size()
	var spacing: float = _get_active_icon_spacing()
	var available_text_width: float = maxf(0.0, content_rect.size.x - icon_draw_size.x - spacing)
	var text_width_limit: float = _get_effective_text_wrap_width(available_text_width)
	var display_lines: PackedStringArray = _get_display_text_lines(text_width_limit)
	var text_size: Vector2 = _get_text_lines_render_size(display_lines)

	var current_x: float = row_position.x

	if icon != null and icon_draw_size != Vector2.ZERO:
		var icon_position: Vector2 = Vector2(
			current_x,
			_get_aligned_child_y(
				row_position.y,
				row_size.y,
				icon_draw_size.y,
				icon_vertical_alignment
			)
		)

		draw_texture_rect(
			icon,
			Rect2(icon_position, icon_draw_size),
			false,
			icon_color
		)

		current_x += icon_draw_size.x + spacing

	if display_lines.size() > 0 and text_size != Vector2.ZERO:
		var text_position: Vector2 = Vector2(
			current_x,
			_get_aligned_child_y(
				row_position.y,
				row_size.y,
				text_size.y,
				VERTICAL_ALIGNMENT_CENTER
			)
		)

		_draw_text_block(text_position, display_lines)

func _draw_text_block(top_left: Vector2, lines: PackedStringArray) -> void:
	var active_font: Font = get_font()
	var line_height: float = active_font.get_height(font_size)

	var line_index: int = 0

	while line_index < lines.size():
		var line: String = lines[line_index]
		var line_top_y: float = top_left.y + float(line_index) * (line_height + float(line_spacing))
		var baseline_y: float = line_top_y + active_font.get_ascent(font_size)

		draw_string(
			active_font,
			Vector2(top_left.x, baseline_y),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			text_color
		)

		line_index += 1

func _get_display_text_lines(max_width: float) -> PackedStringArray:
	var wrapped_lines: PackedStringArray = _get_wrapped_text_lines(max_width)
	return _apply_visible_line_limit(wrapped_lines, max_width)

func _apply_visible_line_limit(lines: PackedStringArray, max_width: float) -> PackedStringArray:
	if max_visible_text_lines <= 0:
		return lines

	if lines.size() <= max_visible_text_lines:
		return lines

	var visible_lines: PackedStringArray = PackedStringArray()
	var line_index: int = 0

	while line_index < max_visible_text_lines and line_index < lines.size():
		visible_lines.append(lines[line_index])
		line_index += 1

	if ellipsize_clipped_text and visible_lines.size() > 0:
		var last_index: int = visible_lines.size() - 1
		visible_lines[last_index] = _ellipsize_line_to_width(
			visible_lines[last_index],
			max_width
		)

	return visible_lines

func _ellipsize_line_to_width(line: String, max_width: float) -> String:
	if not ellipsize_clipped_text:
		return line

	if clipping_ellipsis.is_empty():
		return line

	if max_width <= 0.0:
		return line + clipping_ellipsis

	var ellipsis_width: float = _get_string_width(clipping_ellipsis)

	if ellipsis_width > max_width:
		return _trim_string_to_width(clipping_ellipsis, max_width)

	var candidate: String = line + clipping_ellipsis

	if _get_string_width(candidate) <= max_width:
		return candidate

	var end_index: int = line.length()

	while end_index > 0:
		var trimmed_line: String = line.substr(0, end_index).strip_edges(false, true)
		candidate = trimmed_line + clipping_ellipsis

		if _get_string_width(candidate) <= max_width:
			return candidate

		end_index -= 1

	return clipping_ellipsis

func _trim_string_to_width(value: String, max_width: float) -> String:
	if value.is_empty():
		return ""

	if max_width <= 0.0:
		return ""

	var end_index: int = value.length()

	while end_index > 0:
		var candidate: String = value.substr(0, end_index)

		if _get_string_width(candidate) <= max_width:
			return candidate

		end_index -= 1

	return ""

func _get_effective_text_wrap_width(available_text_width: float) -> float:
	if not text_wrap_enabled:
		return -1.0

	if available_text_width <= 0.0:
		return -1.0

	if text_wrap_width <= 0:
		return available_text_width

	return minf(available_text_width, float(text_wrap_width))

func _get_minimum_text_wrap_width_limit() -> float:
	if not text_wrap_enabled:
		return -1.0

	if text_wrap_width <= 0:
		return -1.0

	return float(text_wrap_width)

func _get_wrapped_text_lines(max_width: float) -> PackedStringArray:
	if text.is_empty():
		return PackedStringArray()

	var source_lines: PackedStringArray = _get_text_lines()

	if not text_wrap_enabled:
		return source_lines

	if max_width <= 0.0:
		return source_lines

	var wrapped_lines: PackedStringArray = PackedStringArray()
	var line_index: int = 0

	while line_index < source_lines.size():
		_append_wrapped_line(source_lines[line_index], max_width, wrapped_lines)
		line_index += 1

	return wrapped_lines

func _append_wrapped_line(line: String, max_width: float, output: PackedStringArray) -> void:
	if line.is_empty():
		output.append("")
		return

	var normalized_line: String = line.replace("\t", " ")
	var words: PackedStringArray = normalized_line.split(" ", false)

	if words.is_empty():
		output.append("")
		return

	var current_line: String = ""
	var word_index: int = 0

	while word_index < words.size():
		var word: String = words[word_index]
		var candidate: String = word

		if not current_line.is_empty():
			candidate = current_line + " " + word

		if _get_string_width(candidate) <= max_width:
			current_line = candidate
		else:
			if not current_line.is_empty():
				output.append(current_line)

			if _get_string_width(word) <= max_width:
				current_line = word
			else:
				var broken_lines: PackedStringArray = _break_long_token(word, max_width)
				var broken_index: int = 0

				while broken_index < maxi(broken_lines.size() - 1, 0):
					output.append(broken_lines[broken_index])
					broken_index += 1

				if broken_lines.size() > 0:
					current_line = broken_lines[broken_lines.size() - 1]
				else:
					current_line = ""

		word_index += 1

	if not current_line.is_empty():
		output.append(current_line)

func _break_long_token(token: String, max_width: float) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()

	if token.is_empty():
		return output

	if max_width <= 0.0:
		output.append(token)
		return output

	var current_line: String = ""
	var character_index: int = 0

	while character_index < token.length():
		var character: String = token.substr(character_index, 1)
		var candidate: String = current_line + character

		if not current_line.is_empty() and _get_string_width(candidate) > max_width:
			output.append(current_line)
			current_line = character
		else:
			current_line = candidate

		character_index += 1

	if not current_line.is_empty():
		output.append(current_line)

	return output

func _get_string_width(value: String) -> float:
	return get_font().get_string_size(
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x

func _draw_progress_bar() -> void:
	if not progress_visible:
		return

	if progress_height <= 0:
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	var bar_height: float = minf(float(progress_height), size.y)
	var bar_y: float = size.y - bar_height

	var background_rect: Rect2 = Rect2(
		Vector2(0.0, bar_y),
		Vector2(size.x, bar_height)
	)

	_draw_progress_segment_clipped_to_stylebox(background_rect, progress_background_color)

	var fill_width: float = floorf(size.x * clampf(progress, 0.0, 1.0))

	if fill_width <= 0.0:
		return

	var fill_x: float = 0.0

	match progress_shrink_direction:
		ProgressShrinkDirection.LEFT_TO_RIGHT:
			fill_x = 0.0

		ProgressShrinkDirection.RIGHT_TO_LEFT:
			fill_x = size.x - fill_width

		_:
			fill_x = 0.0

	var fill_rect: Rect2 = Rect2(
		Vector2(fill_x, bar_y),
		Vector2(fill_width, bar_height)
	)

	_draw_progress_segment_clipped_to_stylebox(fill_rect, progress_color)

func _draw_progress_segment_clipped_to_stylebox(segment_rect: Rect2, color: Color) -> void:
	if color.a <= 0.0:
		return

	if segment_rect.size.x <= 0.0 or segment_rect.size.y <= 0.0:
		return

	var rounded_rect_polygon: PackedVector2Array = _build_stylebox_clip_polygon()

	if rounded_rect_polygon.size() < 3:
		draw_rect(segment_rect, color, true)
		return

	var clipped_polygon: PackedVector2Array = _clip_polygon_to_rect(
		rounded_rect_polygon,
		segment_rect
	)

	if clipped_polygon.size() < 3:
		return

	draw_colored_polygon(clipped_polygon, color)

func _draw_close_button() -> void:
	if not close_button_visible:
		return

	if close_button_size <= 0:
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	var button_rect: Rect2 = get_close_button_rect()

	if button_rect.size.x <= 0.0 or button_rect.size.y <= 0.0:
		return

	if (_close_button_hovered or _close_button_pressed) and close_button_hover_background_color.a > 0.0:
		draw_rect(button_rect, close_button_hover_background_color, true)

	var draw_color: Color = _get_close_button_draw_color()

	if close_button_icon != null:
		var icon_rect: Rect2 = _get_close_button_icon_rect(button_rect)

		if icon_rect.size.x > 0.0 and icon_rect.size.y > 0.0:
			draw_texture_rect(
				close_button_icon,
				icon_rect,
				false,
				draw_color
			)

		return

	_draw_fallback_close_x(button_rect, draw_color)

func _draw_fallback_close_x(button_rect: Rect2, draw_color: Color) -> void:
	var padding: float = maxf(3.0, float(close_button_size) * 0.32)

	var top_left: Vector2 = button_rect.position + Vector2(padding, padding)
	var top_right: Vector2 = Vector2(button_rect.end.x - padding, button_rect.position.y + padding)
	var bottom_left: Vector2 = Vector2(button_rect.position.x + padding, button_rect.end.y - padding)
	var bottom_right: Vector2 = button_rect.end - Vector2(padding, padding)

	draw_line(
		top_left,
		bottom_right,
		draw_color,
		float(close_button_line_width),
		true
	)

	draw_line(
		top_right,
		bottom_left,
		draw_color,
		float(close_button_line_width),
		true
	)

func _get_close_button_draw_color() -> Color:
	if _close_button_pressed:
		return close_button_icon_pressed_color

	if _close_button_hovered:
		return close_button_icon_hover_color

	return close_button_icon_color

func get_close_button_rect() -> Rect2: ## This function returns the [member ToastDisplay.position] for [member ToastDisplay.close_button_icon]
	if not close_button_visible:
		return Rect2()

	var button_size: float = float(close_button_size)
	var margin: float = float(close_button_margin)

	return Rect2(
		Vector2(
			maxf(0.0, size.x - margin - button_size),
			margin
		),
		Vector2(button_size, button_size)
	)

func _get_close_button_icon_rect(button_rect: Rect2) -> Rect2:
	var max_padding: float = minf(button_rect.size.x, button_rect.size.y) * 0.5
	var padding: float = minf(float(close_button_icon_padding), max_padding)

	var icon_position: Vector2 = button_rect.position + Vector2(padding, padding)
	var icon_size_value: Vector2 = button_rect.size - Vector2(padding * 2.0, padding * 2.0)

	return Rect2(
		icon_position,
		Vector2(
			maxf(0.0, icon_size_value.x),
			maxf(0.0, icon_size_value.y)
		)
	)

func _get_aligned_row_position(content_rect: Rect2, row_size: Vector2) -> Vector2:
	return Vector2(
		_get_aligned_row_x(content_rect, row_size.x),
		_get_aligned_row_y(content_rect, row_size.y)
	)

func _get_aligned_row_x(content_rect: Rect2, row_width: float) -> float:
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			return content_rect.position.x

		HORIZONTAL_ALIGNMENT_CENTER:
			return content_rect.position.x + ((content_rect.size.x - row_width) * 0.5)

		HORIZONTAL_ALIGNMENT_RIGHT:
			return content_rect.position.x + content_rect.size.x - row_width

		HORIZONTAL_ALIGNMENT_FILL:
			return content_rect.position.x

		_:
			return content_rect.position.x

func _get_aligned_row_y(content_rect: Rect2, row_height: float) -> float:
	match vertical_alignment:
		VERTICAL_ALIGNMENT_TOP:
			return content_rect.position.y

		VERTICAL_ALIGNMENT_CENTER:
			return content_rect.position.y + ((content_rect.size.y - row_height) * 0.5)

		VERTICAL_ALIGNMENT_BOTTOM:
			return content_rect.position.y + content_rect.size.y - row_height

		VERTICAL_ALIGNMENT_FILL:
			return content_rect.position.y

		_:
			return content_rect.position.y

func _get_aligned_child_y(row_y: float, row_height: float, child_height: float, alignment: VerticalAlignment) -> float:
	match alignment:
		VERTICAL_ALIGNMENT_TOP:
			return row_y

		VERTICAL_ALIGNMENT_CENTER:
			return row_y + ((row_height - child_height) * 0.5)

		VERTICAL_ALIGNMENT_BOTTOM:
			return row_y + row_height - child_height

		VERTICAL_ALIGNMENT_FILL:
			return row_y

		_:
			return row_y + ((row_height - child_height) * 0.5)

func _get_active_icon_spacing() -> float:
	if icon == null:
		return 0.0

	if text.is_empty():
		return 0.0

	if get_icon_draw_size() == Vector2.ZERO:
		return 0.0

	return float(icon_spacing)

func get_font() -> Font:
	if font != null:
		return font

	return get_theme_default_font()

func _get_text_lines() -> PackedStringArray:
	if text.is_empty():
		return PackedStringArray()

	var normalized_text: String = text.replace("\r\n", "\n").replace("\r", "\n")
	return normalized_text.split("\n", true)

func _get_content_rect() -> Rect2:
	var left: float = _get_stylebox_margin(SIDE_LEFT)
	var top: float = _get_stylebox_margin(SIDE_TOP)
	var right: float = _get_stylebox_margin(SIDE_RIGHT) + _get_close_button_reserved_width()
	var bottom: float = _get_stylebox_margin(SIDE_BOTTOM) + _get_progress_reserved_height()

	return Rect2(
		Vector2(left, top),
		Vector2(
			maxf(0.0, size.x - left - right),
			maxf(0.0, size.y - top - bottom)
		)
	)

func _get_horizontal_stylebox_margins() -> float:
	return _get_stylebox_margin(SIDE_LEFT) + _get_stylebox_margin(SIDE_RIGHT)

func _get_vertical_stylebox_margins() -> float:
	return _get_stylebox_margin(SIDE_TOP) + _get_stylebox_margin(SIDE_BOTTOM)

func _get_progress_reserved_height() -> float:
	if not progress_visible:
		return 0.0

	if not progress_reserve_content_space:
		return 0.0

	return float(progress_height)

func _get_close_button_reserved_width() -> float:
	if not close_button_visible:
		return 0.0

	return float(close_button_size + close_button_margin + close_button_spacing)

func _get_close_button_minimum_width() -> float:
	if not close_button_visible:
		return 0.0

	return float(close_button_size + close_button_margin * 2)

func _get_close_button_minimum_height() -> float:
	if not close_button_visible:
		return 0.0

	return float(close_button_size + close_button_margin * 2)

func _get_stylebox_margin(side: Side) -> float:
	var active_stylebox: StyleBox = _get_active_stylebox()

	if active_stylebox == null:
		return 0.0

	return maxf(0.0, active_stylebox.get_content_margin(side))

func _get_active_stylebox() -> StyleBox:
	if stylebox != null:
		return stylebox

	if has_theme_stylebox("panel"):
		return get_theme_stylebox("panel")

	return null

func _observe_current_stylebox() -> void:
	var active_stylebox: StyleBox = _get_active_stylebox()

	if _observed_stylebox == active_stylebox:
		return

	_unobserve_stylebox()

	_observed_stylebox = active_stylebox

	if _observed_stylebox == null:
		return

	var changed_callable: Callable = Callable(self, "_on_observed_stylebox_changed")

	if not _observed_stylebox.changed.is_connected(changed_callable):
		_observed_stylebox.changed.connect(changed_callable)

func _unobserve_stylebox() -> void:
	if _observed_stylebox == null:
		return

	var changed_callable: Callable = Callable(self, "_on_observed_stylebox_changed")

	if _observed_stylebox.changed.is_connected(changed_callable):
		_observed_stylebox.changed.disconnect(changed_callable)

	_observed_stylebox = null

func _on_observed_stylebox_changed() -> void:
	update_minimum_size()
	queue_redraw()

func _observe_current_font() -> void:
	var active_font: Font = get_font()

	if _observed_font == active_font:
		return

	_unobserve_font()

	_observed_font = active_font

	if _observed_font == null:
		return

	var changed_callable: Callable = Callable(self, "_on_observed_font_changed")

	if not _observed_font.changed.is_connected(changed_callable):
		_observed_font.changed.connect(changed_callable)

func _unobserve_font() -> void:
	if _observed_font == null:
		return

	var changed_callable: Callable = Callable(self, "_on_observed_font_changed")

	if _observed_font.changed.is_connected(changed_callable):
		_observed_font.changed.disconnect(changed_callable)

	_observed_font = null

func _on_observed_font_changed() -> void:
	update_minimum_size()
	queue_redraw()

func _build_stylebox_clip_polygon() -> PackedVector2Array:
	var clip_rect: Rect2 = Rect2(Vector2.ZERO, size)
	var radii: PackedFloat32Array = _get_active_stylebox_corner_radii(clip_rect.size)

	return _build_rounded_rect_polygon(clip_rect, radii)

func _get_active_stylebox_corner_radii(rect_size: Vector2) -> PackedFloat32Array:
	var radii: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var active_stylebox: StyleBox = _get_active_stylebox()

	if active_stylebox is StyleBoxFlat:
		var flat_stylebox: StyleBoxFlat = active_stylebox as StyleBoxFlat

		radii[0] = float(flat_stylebox.get_corner_radius(CORNER_TOP_LEFT))
		radii[1] = float(flat_stylebox.get_corner_radius(CORNER_TOP_RIGHT))
		radii[2] = float(flat_stylebox.get_corner_radius(CORNER_BOTTOM_RIGHT))
		radii[3] = float(flat_stylebox.get_corner_radius(CORNER_BOTTOM_LEFT))

	var max_radius: float = minf(rect_size.x * 0.5, rect_size.y * 0.5)

	var index: int = 0

	while index < radii.size():
		radii[index] = clampf(radii[index], 0.0, max_radius)
		index += 1

	return radii

func _build_rounded_rect_polygon(rect: Rect2, radii: PackedFloat32Array) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()

	var top_left_radius: float = radii[0]
	var top_right_radius: float = radii[1]
	var bottom_right_radius: float = radii[2]
	var bottom_left_radius: float = radii[3]

	_append_corner_arc(
		points,
		Vector2(rect.end.x - top_right_radius, rect.position.y + top_right_radius),
		top_right_radius,
		-PI * 0.5,
		0.0
	)

	_append_corner_arc(
		points,
		Vector2(rect.end.x - bottom_right_radius, rect.end.y - bottom_right_radius),
		bottom_right_radius,
		0.0,
		PI * 0.5
	)

	_append_corner_arc(
		points,
		Vector2(rect.position.x + bottom_left_radius, rect.end.y - bottom_left_radius),
		bottom_left_radius,
		PI * 0.5,
		PI
	)

	_append_corner_arc(
		points,
		Vector2(rect.position.x + top_left_radius, rect.position.y + top_left_radius),
		top_left_radius,
		PI,
		PI * 1.5
	)

	return points

func _append_corner_arc(points: PackedVector2Array, center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	if radius <= 0.0:
		points.append(center)
		return

	var segment_count: int = maxi(progress_clip_arc_segments, 4)
	var index: int = 0

	while index <= segment_count:
		var weight: float = float(index) / float(segment_count)
		var angle: float = lerpf(start_angle, end_angle, weight)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius

		points.append(point)
		index += 1

func _clip_polygon_to_rect(polygon: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var output: PackedVector2Array = polygon

	output = _clip_polygon_left(output, rect.position.x)
	output = _clip_polygon_right(output, rect.end.x)
	output = _clip_polygon_top(output, rect.position.y)
	output = _clip_polygon_bottom(output, rect.end.y)

	return output

func _clip_polygon_left(input_polygon: PackedVector2Array, min_x: float) -> PackedVector2Array:
	var output: PackedVector2Array = PackedVector2Array()

	if input_polygon.size() == 0:
		return output

	var previous: Vector2 = input_polygon[input_polygon.size() - 1]
	var previous_inside: bool = previous.x >= min_x

	var index: int = 0

	while index < input_polygon.size():
		var current: Vector2 = input_polygon[index]
		var current_inside: bool = current.x >= min_x

		if current_inside:
			if not previous_inside:
				output.append(_intersect_vertical(previous, current, min_x))

			output.append(current)
		elif previous_inside:
			output.append(_intersect_vertical(previous, current, min_x))

		previous = current
		previous_inside = current_inside
		index += 1

	return output

func _clip_polygon_right(input_polygon: PackedVector2Array, max_x: float) -> PackedVector2Array:
	var output: PackedVector2Array = PackedVector2Array()

	if input_polygon.size() == 0:
		return output

	var previous: Vector2 = input_polygon[input_polygon.size() - 1]
	var previous_inside: bool = previous.x <= max_x

	var index: int = 0

	while index < input_polygon.size():
		var current: Vector2 = input_polygon[index]
		var current_inside: bool = current.x <= max_x

		if current_inside:
			if not previous_inside:
				output.append(_intersect_vertical(previous, current, max_x))

			output.append(current)
		elif previous_inside:
			output.append(_intersect_vertical(previous, current, max_x))

		previous = current
		previous_inside = current_inside
		index += 1

	return output

func _clip_polygon_top(input_polygon: PackedVector2Array, min_y: float) -> PackedVector2Array:
	var output: PackedVector2Array = PackedVector2Array()

	if input_polygon.size() == 0:
		return output

	var previous: Vector2 = input_polygon[input_polygon.size() - 1]
	var previous_inside: bool = previous.y >= min_y

	var index: int = 0

	while index < input_polygon.size():
		var current: Vector2 = input_polygon[index]
		var current_inside: bool = current.y >= min_y

		if current_inside:
			if not previous_inside:
				output.append(_intersect_horizontal(previous, current, min_y))

			output.append(current)
		elif previous_inside:
			output.append(_intersect_horizontal(previous, current, min_y))

		previous = current
		previous_inside = current_inside
		index += 1

	return output

func _clip_polygon_bottom(input_polygon: PackedVector2Array, max_y: float) -> PackedVector2Array: # This function clips the edges of the progress bar when @stylebox corner radii are rounded.
	var output: PackedVector2Array = PackedVector2Array()

	if input_polygon.size() == 0:
		return output

	var previous: Vector2 = input_polygon[input_polygon.size() - 1]
	var previous_inside: bool = previous.y <= max_y

	var index: int = 0

	while index < input_polygon.size():
		var current: Vector2 = input_polygon[index]
		var current_inside: bool = current.y <= max_y

		if current_inside:
			if not previous_inside:
				output.append(_intersect_horizontal(previous, current, max_y))

			output.append(current)
		elif previous_inside:
			output.append(_intersect_horizontal(previous, current, max_y))

		previous = current
		previous_inside = current_inside
		index += 1

	return output

func _intersect_vertical(from: Vector2, to: Vector2, x: float) -> Vector2: #
	var delta_x: float = to.x - from.x

	if is_zero_approx(delta_x):
		return Vector2(x, from.y)

	var weight: float = (x - from.x) / delta_x
	return from.lerp(to, clampf(weight, 0.0, 1.0))

func _intersect_horizontal(from: Vector2, to: Vector2, y: float) -> Vector2: # 
	var delta_y: float = to.y - from.y

	if is_zero_approx(delta_y):
		return Vector2(from.x, y)

	var weight: float = (y - from.y) / delta_y
	return from.lerp(to, clampf(weight, 0.0, 1.0))
