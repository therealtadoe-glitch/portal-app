@tool
class_name AdvancedBottomTabBar
extends Control

signal tab_selected(index: int, tab_id: StringName)
signal tab_reselected(index: int, tab_id: StringName)
signal page_changed(index: int, previous_index: int, tab_id: StringName)

class TabEntry:
	extends RefCounted

	var id: StringName = &""
	var title: String = ""
	var icon: Texture2D = null
	var page: Control = null
	var button: Button = null
	var label: Label = null
	var icon_rect: TextureRect = null


const ROOT_NAME: StringName = &"_advanced_bottom_tabs_root"
const PAGE_STACK_NAME: StringName = &"_advanced_bottom_tabs_page_stack"
const BAR_FRAME_NAME: StringName = &"_advanced_bottom_tabs_bar_frame"
const BAR_LAYER_NAME: StringName = &"_advanced_bottom_tabs_bar_layer"
const INDICATOR_NAME: StringName = &"_advanced_bottom_tabs_indicator"
const BUTTON_ROW_NAME: StringName = &"_advanced_bottom_tabs_button_row"

@export_group("Tabs")
@export var tab_titles: PackedStringArray = PackedStringArray(["Home", "Discover", "Library", "Profile"]):
	set(value):
		tab_titles = _sanitize_tab_titles(value)
		_request_rebuild()

@export_range(0, 32, 1) var initial_tab_index: int = 0:
	set(value):
		initial_tab_index = maxi(value, 0)
		if is_inside_tree() and _tabs.size() > 0:
			switch_to(clampi(initial_tab_index, 0, _tabs.size() - 1), true)

@export_group("Layout")
@export_range(56, 120, 1) var bar_height: int = 76:
	set(value):
		bar_height = maxi(value, 56)
		_apply_layout()

@export_range(0, 48, 1) var bar_padding_horizontal: int = 12:
	set(value):
		bar_padding_horizontal = maxi(value, 0)
		_apply_layout()

@export_range(0, 32, 1) var bar_corner_radius: int = 22:
	set(value):
		bar_corner_radius = maxi(value, 0)
		_apply_visuals()

@export_range(2, 12, 1) var indicator_height: int = 4:
	set(value):
		indicator_height = maxi(value, 2)
		_apply_visuals()
		_update_indicator(false)

@export_range(0.2, 1.0, 0.01) var indicator_width_ratio: float = 0.46:
	set(value):
		indicator_width_ratio = clampf(value, 0.2, 1.0)
		_update_indicator(false)

@export_range(0, 24, 1) var indicator_bottom_margin: int = 8:
	set(value):
		indicator_bottom_margin = maxi(value, 0)
		_update_indicator(false)

@export_range(12, 32, 1) var icon_size: int = 22:
	set(value):
		icon_size = maxi(value, 12)
		_refresh_button_content()

@export_range(10, 24, 1) var tab_font_size: int = 13:
	set(value):
		tab_font_size = maxi(value, 10)
		_refresh_button_content()

@export_range(1.0, 1.2, 0.01) var active_tab_scale: float = 1.04:
	set(value):
		active_tab_scale = clampf(value, 1.0, 1.2)
		_update_button_states(false)

@export_group("Animation")
@export_range(0.05, 0.6, 0.01) var animation_duration: float = 0.24:
	set(value):
		animation_duration = clampf(value, 0.05, 0.6)

@export var animate_pages: bool = true
@export var animate_indicator: bool = true
@export var animate_buttons: bool = true

@export_group("Colors")
@export var page_background_color: Color = Color(0.035, 0.038, 0.048, 1.0):
	set(value):
		page_background_color = value
		_apply_visuals()

@export var bar_background_color: Color = Color(0.075, 0.078, 0.092, 0.98):
	set(value):
		bar_background_color = value
		_apply_visuals()

@export var tab_active_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		tab_active_color = value
		_apply_visuals()

@export var tab_inactive_color: Color = Color(0.62, 0.64, 0.70, 1.0):
	set(value):
		tab_inactive_color = value
		_apply_visuals()

@export var tab_active_background_color: Color = Color(1.0, 1.0, 1.0, 0.075):
	set(value):
		tab_active_background_color = value
		_apply_visuals()

@export var tab_hover_background_color: Color = Color(1.0, 1.0, 1.0, 0.06):
	set(value):
		tab_hover_background_color = value
		_apply_visuals()

@export var indicator_color: Color = Color(0.45, 0.66, 1.0, 1.0):
	set(value):
		indicator_color = value
		_apply_visuals()


var _root: VBoxContainer = null
var _page_stack: Control = null
var _bar_frame: PanelContainer = null
var _bar_layer: Control = null
var _indicator: Panel = null
var _button_row: HBoxContainer = null

var _tabs: Array[TabEntry] = []
var _active_index: int = -1

var _indicator_tween: Tween = null
var _page_tween: Tween = null
var _button_tween: Tween = null

var _pending_rebuild: bool = false


func _ready() -> void:
	_ensure_nodes()
	_rebuild_from_exported_titles()
	_apply_visuals()
	_apply_layout()
	call_deferred("_sync_after_layout")


func _exit_tree() -> void:
	_kill_tweens()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fill_parent(_root)
		_fit_pages()
		_update_indicator(false)
	elif what == NOTIFICATION_THEME_CHANGED:
		_apply_visuals()


func add_tab(tab_id: StringName, title: String, page: Control = null, icon: Texture2D = null) -> int:
	_ensure_nodes()

	var entry: TabEntry = TabEntry.new()
	entry.id = _make_unique_tab_id(tab_id, title)
	entry.title = title.strip_edges()
	if entry.title.is_empty():
		entry.title = "Tab %d" % (_tabs.size() + 1)
	entry.icon = icon

	if page == null:
		entry.page = _create_default_page(entry.title)
	else:
		entry.page = page

	_tabs.append(entry)
	_attach_page(entry.page)

	var index: int = _tabs.size() - 1
	var button: Button = _create_tab_button(entry, index)
	entry.button = button
	_button_row.add_child(button)
	_update_button_references()

	if _active_index == -1:
		switch_to(0, false)
	else:
		entry.page.visible = false
		_update_button_states(false)
		_update_indicator(false)

	call_deferred("_sync_after_layout")
	return index


func remove_tab(index: int, free_page: bool = true) -> void:
	if not _is_valid_tab_index(index):
		return

	_kill_tweens()

	var entry: TabEntry = _tabs[index]

	if is_instance_valid(entry.button):
		entry.button.queue_free()

	if is_instance_valid(entry.page):
		if entry.page.get_parent() == _page_stack:
			_page_stack.remove_child(entry.page)
		if free_page:
			entry.page.queue_free()

	_tabs.remove_at(index)
	_rebuild_button_row()

	if _tabs.is_empty():
		_active_index = -1
		_update_indicator(false)
		return

	_active_index = clampi(_active_index, 0, _tabs.size() - 1)
	switch_to(_active_index, false)


func clear_tabs(free_pages: bool = true) -> void:
	_kill_tweens()

	for entry: TabEntry in _tabs:
		if is_instance_valid(entry.button):
			entry.button.queue_free()

		if is_instance_valid(entry.page):
			if entry.page.get_parent() == _page_stack:
				_page_stack.remove_child(entry.page)
			if free_pages:
				entry.page.queue_free()

	_tabs.clear()
	_active_index = -1
	_update_indicator(false)


func set_tab_page(index: int, page: Control, free_previous: bool = false) -> void:
	if not _is_valid_tab_index(index) or page == null:
		return

	var entry: TabEntry = _tabs[index]
	var previous_page: Control = entry.page

	if previous_page == page:
		return

	if is_instance_valid(previous_page):
		if previous_page.get_parent() == _page_stack:
			_page_stack.remove_child(previous_page)
		if free_previous:
			previous_page.queue_free()

	entry.page = page
	_attach_page(page)

	if index == _active_index:
		_show_only_page(index)
	else:
		page.visible = false


func set_tab_icon(index: int, icon: Texture2D) -> void:
	if not _is_valid_tab_index(index):
		return

	var entry: TabEntry = _tabs[index]
	entry.icon = icon

	if is_instance_valid(entry.icon_rect):
		entry.icon_rect.texture = icon
		entry.icon_rect.visible = icon != null

	_refresh_button_content()


func set_tab_title(index: int, title: String) -> void:
	if not _is_valid_tab_index(index):
		return

	var clean_title: String = title.strip_edges()
	if clean_title.is_empty():
		clean_title = "Tab %d" % (index + 1)

	var entry: TabEntry = _tabs[index]
	entry.title = clean_title

	if is_instance_valid(entry.label):
		entry.label.text = clean_title

	if is_instance_valid(entry.button):
		entry.button.tooltip_text = clean_title


func switch_to(index: int, animated: bool = true) -> void:
	if not _is_valid_tab_index(index):
		return

	var entry: TabEntry = _tabs[index]

	if index == _active_index:
		_update_button_states(animated)
		_update_indicator(animated)
		tab_reselected.emit(index, entry.id)
		return

	var previous_index: int = _active_index
	_active_index = index

	_transition_page(previous_index, index, animated and animate_pages)
	_update_button_states(animated and animate_buttons)
	_update_indicator(animated and animate_indicator)

	tab_selected.emit(index, entry.id)
	page_changed.emit(index, previous_index, entry.id)


func switch_to_id(tab_id: StringName, animated: bool = true) -> void:
	var index: int = get_tab_index(tab_id)
	if index != -1:
		switch_to(index, animated)


func get_tab_index(tab_id: StringName) -> int:
	for index: int in range(_tabs.size()):
		if _tabs[index].id == tab_id:
			return index
	return -1


func get_active_index() -> int:
	return _active_index


func get_active_tab_id() -> StringName:
	if not _is_valid_tab_index(_active_index):
		return &""
	return _tabs[_active_index].id


func get_active_page() -> Control:
	if not _is_valid_tab_index(_active_index):
		return null
	return _tabs[_active_index].page


func get_tab_count() -> int:
	return _tabs.size()


func _ensure_nodes() -> void:
	if is_instance_valid(_root) and _root.get_parent() == self:
		return

	var existing_root: Node = get_node_or_null(NodePath(String(ROOT_NAME)))
	if existing_root != null:
		remove_child(existing_root)
		existing_root.free()

	_root = VBoxContainer.new()
	_root.name = ROOT_NAME
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_root, false, Node.INTERNAL_MODE_FRONT)
	_fill_parent(_root)

	_page_stack = Control.new()
	_page_stack.name = PAGE_STACK_NAME
	_page_stack.clip_contents = true
	_page_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	_page_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_page_stack, false, Node.INTERNAL_MODE_FRONT)

	_bar_frame = PanelContainer.new()
	_bar_frame.name = BAR_FRAME_NAME
	_bar_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	_bar_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_frame.size_flags_vertical = Control.SIZE_SHRINK_END
	_root.add_child(_bar_frame, false, Node.INTERNAL_MODE_FRONT)

	_bar_layer = Control.new()
	_bar_layer.name = BAR_LAYER_NAME
	_bar_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_bar_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar_frame.add_child(_bar_layer, false, Node.INTERNAL_MODE_FRONT)

	_indicator = Panel.new()
	_indicator.name = INDICATOR_NAME
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_layer.add_child(_indicator, false, Node.INTERNAL_MODE_FRONT)

	_button_row = HBoxContainer.new()
	_button_row.name = BUTTON_ROW_NAME
	_button_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 0)
	_bar_layer.add_child(_button_row, false, Node.INTERNAL_MODE_FRONT)
	_fill_parent(_button_row)

	if not _bar_layer.resized.is_connected(_on_bar_layer_resized):
		_bar_layer.resized.connect(_on_bar_layer_resized)


func _rebuild_from_exported_titles() -> void:
	_pending_rebuild = false

	if not is_inside_tree():
		return

	_ensure_nodes()
	clear_tabs(true)

	for index: int in range(tab_titles.size()):
		var title: String = tab_titles[index]
		var id: StringName = StringName(_make_default_id(title, index))
		add_tab(id, title, null, null)

	if not _tabs.is_empty():
		var safe_index: int = clampi(initial_tab_index, 0, _tabs.size() - 1)
		switch_to(safe_index, false)

	_apply_visuals()
	_apply_layout()
	call_deferred("_sync_after_layout")


func _request_rebuild() -> void:
	if not is_inside_tree():
		return

	if _pending_rebuild:
		return

	_pending_rebuild = true
	notify_property_list_changed()
	call_deferred("_rebuild_from_exported_titles")


func _apply_layout() -> void:
	if not is_instance_valid(_bar_frame):
		return

	_bar_frame.custom_minimum_size = Vector2(0.0, float(bar_height))

	if is_instance_valid(_button_row):
		_fill_parent(_button_row)
		_button_row.offset_left = float(bar_padding_horizontal)
		_button_row.offset_right = -float(bar_padding_horizontal)

	_refresh_button_content()
	_fit_pages()
	_update_indicator(false)
	queue_redraw()


func _apply_visuals() -> void:
	if not is_instance_valid(_bar_frame):
		return

	_bar_frame.add_theme_stylebox_override(
		"panel",
		_make_stylebox(bar_background_color, bar_corner_radius)
	)

	if is_instance_valid(_indicator):
		_indicator.add_theme_stylebox_override(
			"panel",
			_make_stylebox(indicator_color, indicator_height)
		)

	for entry: TabEntry in _tabs:
		_apply_button_style(entry)

	_update_button_states(false)
	queue_redraw()


func _refresh_button_content() -> void:
	for entry: TabEntry in _tabs:
		if is_instance_valid(entry.icon_rect):
			entry.icon_rect.custom_minimum_size = Vector2(float(icon_size), float(icon_size))
			entry.icon_rect.visible = entry.icon != null

		if is_instance_valid(entry.label):
			entry.label.add_theme_font_size_override("font_size", tab_font_size)

		if is_instance_valid(entry.button):
			entry.button.custom_minimum_size = Vector2(0.0, float(bar_height))

	_update_button_states(false)


func _create_tab_button(entry: TabEntry, index: int) -> Button:
	var button: Button = Button.new()
	button.name = StringName("TabButton_%s" % String(entry.id))
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = entry.title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, float(bar_height))
	button.clip_contents = false
	button.pressed.connect(Callable(self, "_on_tab_button_pressed").bind(index))

	var content: VBoxContainer = VBoxContainer.new()
	content.name = &"Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)
	_fill_parent(content)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = &"Icon"
	icon_rect.texture = entry.icon
	icon_rect.visible = entry.icon != null
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(float(icon_size), float(icon_size))
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(icon_rect)

	var label: Label = Label.new()
	label.name = &"Label"
	label.text = entry.title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", tab_font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(label)

	entry.icon_rect = icon_rect
	entry.label = label

	_apply_button_style(entry)
	return button


func _rebuild_button_row() -> void:
	if not is_instance_valid(_button_row):
		return

	for child: Node in _button_row.get_children():
		child.queue_free()

	for index: int in range(_tabs.size()):
		var entry: TabEntry = _tabs[index]
		var button: Button = _create_tab_button(entry, index)
		entry.button = button
		_button_row.add_child(button)

	_update_button_references()
	_update_button_states(false)
	_update_indicator(false)


func _update_button_references() -> void:
	for index: int in range(_tabs.size()):
		var entry: TabEntry = _tabs[index]
		if is_instance_valid(entry.button):
			entry.button.tooltip_text = entry.title


func _apply_button_style(entry: TabEntry) -> void:
	if not is_instance_valid(entry.button):
		return

	var button: Button = entry.button
	var active: bool = _tabs.find(entry) == _active_index

	button.add_theme_stylebox_override(
		"normal",
		_make_stylebox(tab_active_background_color if active else Color(1.0, 1.0, 1.0, 0.0), 18)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_stylebox(tab_hover_background_color, 18)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_stylebox(tab_active_background_color, 18)
	)
	button.add_theme_stylebox_override(
		"focus",
		_make_stylebox(Color(1.0, 1.0, 1.0, 0.0), 18)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_make_stylebox(Color(1.0, 1.0, 1.0, 0.0), 18)
	)


func _update_button_states(animated: bool) -> void:
	if _button_tween != null and _button_tween.is_running():
		_button_tween.kill()

	if animated:
		_button_tween = create_tween()
		_button_tween.set_parallel(true)
		_button_tween.set_trans(Tween.TRANS_CUBIC)
		_button_tween.set_ease(Tween.EASE_OUT)

	for index: int in range(_tabs.size()):
		var entry: TabEntry = _tabs[index]
		var active: bool = index == _active_index
		var target_color: Color = tab_active_color if active else tab_inactive_color
		var target_scale: Vector2 = Vector2.ONE * (active_tab_scale if active else 1.0)

		_apply_button_style(entry)

		if is_instance_valid(entry.button):
			entry.button.pivot_offset = entry.button.size * 0.5
			if animated and _button_tween != null:
				_button_tween.tween_property(entry.button, "scale", target_scale, animation_duration)
			else:
				entry.button.scale = target_scale

		if is_instance_valid(entry.label):
			if animated and _button_tween != null:
				_button_tween.tween_property(entry.label, "modulate", target_color, animation_duration)
			else:
				entry.label.modulate = target_color

		if is_instance_valid(entry.icon_rect):
			if animated and _button_tween != null:
				_button_tween.tween_property(entry.icon_rect, "modulate", target_color, animation_duration)
			else:
				entry.icon_rect.modulate = target_color


func _transition_page(previous_index: int, next_index: int, animated: bool) -> void:
	if not _is_valid_tab_index(next_index):
		return

	if _page_tween != null and _page_tween.is_running():
		_page_tween.kill()

	var next_page: Control = _tabs[next_index].page
	if not is_instance_valid(next_page):
		return

	_fit_pages()

	if not animated or previous_index == -1 or not _is_valid_tab_index(previous_index):
		_show_only_page(next_index)
		return

	var previous_page: Control = _tabs[previous_index].page
	if not is_instance_valid(previous_page):
		_show_only_page(next_index)
		return

	var direction: float = 1.0
	if next_index < previous_index:
		direction = -1.0

	var stack_width: float = maxf(_page_stack.size.x, 1.0)

	next_page.visible = true
	next_page.position = Vector2(stack_width * direction, 0.0)
	next_page.modulate = Color(1.0, 1.0, 1.0, 0.0)

	previous_page.visible = true
	previous_page.position = Vector2.ZERO
	previous_page.modulate = Color.WHITE

	_page_tween = create_tween()
	_page_tween.set_parallel(true)
	_page_tween.set_trans(Tween.TRANS_CUBIC)
	_page_tween.set_ease(Tween.EASE_OUT)

	_page_tween.tween_property(next_page, "position", Vector2.ZERO, animation_duration)
	_page_tween.tween_property(next_page, "modulate:a", 1.0, animation_duration)

	_page_tween.tween_property(
		previous_page,
		"position",
		Vector2(-stack_width * 0.16 * direction, 0.0),
		animation_duration
	)
	_page_tween.tween_property(previous_page, "modulate:a", 0.0, animation_duration * 0.82)

	_page_tween.finished.connect(
		Callable(self, "_on_page_transition_finished").bind(next_index, previous_page)
	)


func _on_page_transition_finished(next_index: int, previous_page: Control) -> void:
	if is_instance_valid(previous_page):
		previous_page.visible = false
		previous_page.position = Vector2.ZERO
		previous_page.modulate = Color.WHITE

	_show_only_page(next_index)


func _show_only_page(index: int) -> void:
	for page_index: int in range(_tabs.size()):
		var page: Control = _tabs[page_index].page
		if is_instance_valid(page):
			page.visible = page_index == index
			page.position = Vector2.ZERO
			page.modulate = Color.WHITE


func _attach_page(page: Control) -> void:
	if page == null:
		return

	var current_parent: Node = page.get_parent()
	if current_parent != null and current_parent != _page_stack:
		current_parent.remove_child(page)

	if page.get_parent() != _page_stack:
		_page_stack.add_child(page)

	page.mouse_filter = Control.MOUSE_FILTER_PASS
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill_parent(page)
	page.visible = false


func _fit_pages() -> void:
	if not is_instance_valid(_page_stack):
		return

	for entry: TabEntry in _tabs:
		if is_instance_valid(entry.page):
			_fill_parent(entry.page)
			entry.page.size = _page_stack.size


func _update_indicator(animated: bool) -> void:
	if not is_instance_valid(_indicator) or not is_instance_valid(_bar_layer):
		return

	var count: int = _tabs.size()
	if count <= 0 or _active_index < 0:
		_indicator.visible = false
		return

	var layer_width: float = _bar_layer.size.x
	if layer_width <= 1.0:
		return

	_indicator.visible = true

	var available_width: float = maxf(layer_width - float(bar_padding_horizontal * 2), 1.0)
	var cell_width: float = available_width / float(count)
	var target_width: float = maxf(24.0, cell_width * indicator_width_ratio)
	target_width = minf(target_width, maxf(cell_width - 12.0, 12.0))

	var target_x: float = float(bar_padding_horizontal) + (cell_width * float(_active_index)) + ((cell_width - target_width) * 0.5)
	var target_y: float = maxf(_bar_layer.size.y - float(indicator_bottom_margin) - float(indicator_height), 0.0)
	var target_position: Vector2 = Vector2(target_x, target_y)
	var target_size: Vector2 = Vector2(target_width, float(indicator_height))

	if _indicator_tween != null and _indicator_tween.is_running():
		_indicator_tween.kill()

	if animated:
		_indicator_tween = create_tween()
		_indicator_tween.set_parallel(true)
		_indicator_tween.set_trans(Tween.TRANS_CUBIC)
		_indicator_tween.set_ease(Tween.EASE_OUT)
		_indicator_tween.tween_property(_indicator, "position", target_position, animation_duration)
		_indicator_tween.tween_property(_indicator, "size", target_size, animation_duration)
	else:
		_indicator.position = target_position
		_indicator.size = target_size


func _on_tab_button_pressed(index: int) -> void:
	switch_to(index, true)


func _on_bar_layer_resized() -> void:
	_fill_parent(_button_row)
	if is_instance_valid(_button_row):
		_button_row.offset_left = float(bar_padding_horizontal)
		_button_row.offset_right = -float(bar_padding_horizontal)

	_fit_pages()
	_update_indicator(false)
	_update_button_states(false)


func _sync_after_layout() -> void:
	_fill_parent(_root)
	_fit_pages()
	_update_indicator(false)
	_update_button_states(false)


func _create_default_page(title: String) -> Control:
	var page: PanelContainer = PanelContainer.new()
	page.name = StringName("Page_%s" % _make_safe_node_name(title, "TabPage"))
	page.add_theme_stylebox_override("panel", _make_stylebox(page_background_color, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.name = &"PageMargin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	page.add_child(margin)

	var label: Label = Label.new()
	label.name = &"PageTitle"
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 1.0))
	label.add_theme_font_size_override("font_size", 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(label)

	return page


func _make_stylebox(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _fill_parent(control: Control) -> void:
	if not is_instance_valid(control):
		return

	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _sanitize_tab_titles(value: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()

	for title: String in value:
		var clean_title: String = title.strip_edges()
		if not clean_title.is_empty():
			result.append(clean_title)

	if result.is_empty():
		result.append("Home")

	return result


func _make_default_id(title: String, index: int) -> String:
	var text: String = title.strip_edges().to_lower()
	text = text.replace(" ", "_")
	text = text.replace("-", "_")
	text = text.replace(".", "_")
	text = text.replace("/", "_")
	text = text.replace("\\", "_")
	text = text.replace(":", "_")

	if text.is_empty():
		text = "tab_%d" % index

	return text


func _make_unique_tab_id(requested_id: StringName, title: String) -> StringName:
	var base_text: String = String(requested_id)

	if base_text.is_empty():
		base_text = _make_default_id(title, _tabs.size())

	var candidate: StringName = StringName(base_text)
	var suffix: int = 2

	while _contains_tab_id(candidate):
		candidate = StringName("%s_%d" % [base_text, suffix])
		suffix += 1

	return candidate


func _contains_tab_id(tab_id: StringName) -> bool:
	for entry: TabEntry in _tabs:
		if entry.id == tab_id:
			return true
	return false


func _make_safe_node_name(text: String, fallback: String) -> String:
	var result: String = text.strip_edges()

	if result.is_empty():
		return fallback

	result = result.replace(" ", "_")
	result = result.replace(".", "_")
	result = result.replace(":", "_")
	result = result.replace("@", "_")
	result = result.replace("/", "_")
	result = result.replace("\\", "_")
	result = result.replace("%", "_")
	result = result.replace("&", "_")
	result = result.replace("#", "_")

	return result


func _is_valid_tab_index(index: int) -> bool:
	return index >= 0 and index < _tabs.size()


func _kill_tweens() -> void:
	if _indicator_tween != null and _indicator_tween.is_running():
		_indicator_tween.kill()

	if _page_tween != null and _page_tween.is_running():
		_page_tween.kill()

	if _button_tween != null and _button_tween.is_running():
		_button_tween.kill()
