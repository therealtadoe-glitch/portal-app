@tool
class_name AppNavigationShell
extends Control

signal tab_changed(tab_id: String)
signal page_changed(tab_id: String, route_id: String, title: String)
signal action_pressed(action_id: String)
signal back_pressed

const ROOT_NAME: StringName = &"Root"
const LAYOUT_NAME: StringName = &"Layout"
const APP_BAR_NAME: StringName = &"AppBar"
const APP_BAR_ROW_NAME: StringName = &"AppBarRow"
const BACK_BUTTON_NAME: StringName = &"BackButton"
const TITLE_STACK_NAME: StringName = &"TitleStack"
const TITLE_LABEL_NAME: StringName = &"TitleLabel"
const SUBTITLE_LABEL_NAME: StringName = &"SubtitleLabel"
const ACTION_BAR_NAME: StringName = &"ActionBar"
const CONTENT_PANEL_NAME: StringName = &"ContentPanel"
const CONTENT_HOST_NAME: StringName = &"ContentHost"
const BOTTOM_BAR_NAME: StringName = &"BottomBar"
const BOTTOM_ROW_NAME: StringName = &"BottomRow"

@export_group("Layout")
@export var app_bar_height: float = 70.0:
	set(value):
		app_bar_height = maxf(value, 52.0)
		_refresh_layout()

@export var bottom_bar_height: float = 78.0:
	set(value):
		bottom_bar_height = maxf(value, 58.0)
		_refresh_layout()

@export_group("Colors")
@export var background_color: Color = Color("10131a"):
	set(value):
		background_color = value
		_refresh_styles()

@export var app_bar_color: Color = Color("141925"):
	set(value):
		app_bar_color = value
		_refresh_styles()

@export var bottom_bar_color: Color = Color("141925"):
	set(value):
		bottom_bar_color = value
		_refresh_styles()

@export var content_color: Color = Color("10131a"):
	set(value):
		content_color = value
		_refresh_styles()

@export var elevated_color: Color = Color("1d2430"):
	set(value):
		elevated_color = value
		_refresh_styles()

@export var border_color: Color = Color("2a3345"):
	set(value):
		border_color = value
		_refresh_styles()

@export var accent_color: Color = Color("3ca1fe"):
	set(value):
		accent_color = value
		_refresh_styles()

@export var text_color: Color = Color("f4f7fb"):
	set(value):
		text_color = value
		_refresh_styles()

@export var muted_text_color: Color = Color("aab4c4"):
	set(value):
		muted_text_color = value
		_refresh_styles()

@export_group("Icons")
@export_file var back_button_icon_path: String = "res://assets/icons/interface-arrows-left--arrow-keyboard-left--Streamline-Core.svg":
	set(value):
		back_button_icon_path = value.strip_edges()
		_refresh_icons()

@export_range(12, 48, 1) var toolbar_icon_max_width: int = 20:
	set(value):
		toolbar_icon_max_width = maxi(value, 12)
		_refresh_icons()

@export_range(16, 56, 1) var tab_icon_max_width: int = 24:
	set(value):
		tab_icon_max_width = maxi(value, 16)
		_refresh_icons()

var _tabs: Array[Dictionary] = []
var _stacks: Dictionary = {}
var _current_tab_id: String = ""
var _tab_history: PackedStringArray = PackedStringArray()

var _root: PanelContainer
var _layout: VBoxContainer
var _app_bar: PanelContainer
var _back_button: Button
var _title_label: Label
var _subtitle_label: Label
var _action_bar: HBoxContainer
var _content_panel: PanelContainer
var _content_host: Control
var _bottom_bar: PanelContainer
var _bottom_row: HBoxContainer
var _bottom_buttons: Dictionary = {}


func _ready() -> void:
	_ensure_ui()
	_refresh_layout()
	_refresh_styles()
	_refresh_nav_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()
	elif what == NOTIFICATION_RESIZED:
		_refresh_layout()


func set_tabs(tab_specs: Array) -> void:
	_tabs.clear()

	for tab_value: Variant in tab_specs:
		if not (tab_value is Dictionary):
			continue

		var tab_spec: Dictionary = tab_value
		var tab_id: String = String(tab_spec.get("id", "")).strip_edges()
		if tab_id.is_empty():
			continue

		var title: String = String(tab_spec.get("title", tab_id.capitalize())).strip_edges()
		if title.is_empty():
			title = tab_id.capitalize()

		var icon_path: String = String(tab_spec.get("icon_path", "")).strip_edges()
		var icon_texture: Texture2D = _texture_from_variant(tab_spec.get("icon", null))

		var show_label: bool = false
		var show_label_value: Variant = tab_spec.get("show_label", false)
		if show_label_value is bool:
			show_label = show_label_value

		_tabs.append({
			"id": tab_id,
			"title": title,
			"icon_path": icon_path,
			"icon": icon_texture,
			"show_label": show_label
		})

		if not _stacks.has(tab_id):
			_stacks[tab_id] = []

	if _current_tab_id.is_empty() and not _tabs.is_empty():
		_current_tab_id = String(_tabs[0].get("id", ""))
		_tab_history.append(_current_tab_id)

	_rebuild_bottom_nav()
	_refresh_nav_state()


func set_back_button_icon(icon_path: String) -> void:
	back_button_icon_path = icon_path.strip_edges()
	_refresh_icons()


func set_tab_icon(tab_id: String, icon_path: String, icon: Texture2D = null) -> void:
	var clean_tab_id: String = tab_id.strip_edges()
	if clean_tab_id.is_empty():
		return

	var clean_icon_path: String = icon_path.strip_edges()
	for index: int in range(_tabs.size()):
		var tab_spec: Dictionary = _tabs[index]
		if String(tab_spec.get("id", "")) != clean_tab_id:
			continue

		tab_spec["icon_path"] = clean_icon_path
		tab_spec["icon"] = icon
		_tabs[index] = tab_spec

		var button: Button = _bottom_buttons.get(clean_tab_id, null) as Button
		if button != null:
			_apply_icon_only_button(
				button,
				clean_icon_path,
				String(tab_spec.get("title", clean_tab_id.capitalize())),
				true,
				icon,
				tab_icon_max_width
			)
			_style_tab_button(button)

		queue_redraw()
		return


func set_tab_icons(tab_icons: Dictionary) -> void:
	for tab_key: Variant in tab_icons.keys():
		var tab_id: String = String(tab_key)
		var icon_value: Variant = tab_icons.get(tab_key, null)
		var icon_texture: Texture2D = _texture_from_variant(icon_value)
		var icon_path: String = ""
		if icon_value is String:
			icon_path = String(icon_value)
		set_tab_icon(tab_id, icon_path, icon_texture)


func reset_navigation() -> void:
	for tab_spec: Dictionary in _tabs:
		var tab_id: String = String(tab_spec.get("id", ""))
		_clear_stack(tab_id)
		_stacks[tab_id] = []

	_clear_content_host()
	_refresh_nav_state()


func set_action_buttons(actions: Array) -> void:
	_ensure_ui()

	for child: Node in _action_bar.get_children():
		_action_bar.remove_child(child)
		child.queue_free()

	for action_value: Variant in actions:
		if not (action_value is Dictionary):
			continue

		var action: Dictionary = action_value
		var action_id: String = String(action.get("id", "")).strip_edges()
		var title: String = String(action.get("title", action_id)).strip_edges()
		var icon_path: String = String(action.get("icon_path", "")).strip_edges()
		var icon_texture: Texture2D = _texture_from_variant(action.get("icon", null))

		if action_id.is_empty() or title.is_empty():
			continue

		var button: Button = Button.new()
		button.name = "%sActionButton" % action_id.capitalize()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(42.0, 38.0)
		button.pressed.connect(_on_action_button_pressed.bind(action_id))

		_apply_icon_only_button(button, icon_path, title, true, icon_texture, toolbar_icon_max_width)

		_action_bar.add_child(button)

	_refresh_styles()

func set_tab_root_page(tab_id: String, title: String, subtitle: String, page: Control) -> void:
	var clean_tab_id: String = tab_id.strip_edges()
	if clean_tab_id.is_empty() or page == null:
		return

	if not _stacks.has(clean_tab_id):
		_stacks[clean_tab_id] = []

	_clear_stack(clean_tab_id)

	var stack: Array[Dictionary] = []
	stack.append(_make_entry(clean_tab_id, title, subtitle, page))
	_stacks[clean_tab_id] = stack

	if _current_tab_id.is_empty():
		_current_tab_id = clean_tab_id
		_tab_history.append(clean_tab_id)

	if _current_tab_id == clean_tab_id:
		_show_current_page()


func select_tab(tab_id: String, track_history: bool = true) -> void:
	var clean_tab_id: String = tab_id.strip_edges()
	if clean_tab_id.is_empty():
		return

	if not _has_tab(clean_tab_id):
		return

	if clean_tab_id == _current_tab_id:
		pop_to_root(clean_tab_id)
		return

	_current_tab_id = clean_tab_id

	if track_history:
		if _tab_history.is_empty() or _tab_history[_tab_history.size() - 1] != clean_tab_id:
			_tab_history.append(clean_tab_id)

	_show_current_page()
	tab_changed.emit(clean_tab_id)


func push_page(route_id: String, title: String, subtitle: String, page: Control) -> void:
	if _current_tab_id.is_empty() or page == null:
		return

	var stack: Array = _get_stack(_current_tab_id)
	stack.append(_make_entry(route_id, title, subtitle, page))
	_stacks[_current_tab_id] = stack

	_show_current_page()


func replace_current_page(route_id: String, title: String, subtitle: String, page: Control) -> void:
	if _current_tab_id.is_empty() or page == null:
		return

	var stack: Array = _get_stack(_current_tab_id)
	if stack.is_empty():
		stack.append(_make_entry(route_id, title, subtitle, page))
	else:
		var previous_entry: Dictionary = stack[stack.size() - 1]
		var previous_page: Control = previous_entry.get("page", null) as Control
		if previous_page != null and previous_page != page:
			_detach_or_free_page(previous_page)

		stack[stack.size() - 1] = _make_entry(route_id, title, subtitle, page)

	_stacks[_current_tab_id] = stack
	_show_current_page()


func pop_to_root(tab_id: String = "") -> void:
	var target_tab_id: String = tab_id.strip_edges()
	if target_tab_id.is_empty():
		target_tab_id = _current_tab_id

	var stack: Array = _get_stack(target_tab_id)
	while stack.size() > 1:
		var removed_entry: Dictionary = stack.pop_back()
		var removed_page: Control = removed_entry.get("page", null) as Control
		if removed_page != null:
			_detach_or_free_page(removed_page)

	_stacks[target_tab_id] = stack

	if target_tab_id == _current_tab_id:
		_show_current_page()


func can_go_back() -> bool:
	var stack: Array = _get_stack(_current_tab_id)
	return stack.size() > 1 or _tab_history.size() > 1


func go_back() -> void:
	var stack: Array = _get_stack(_current_tab_id)

	if stack.size() > 1:
		var removed_entry: Dictionary = stack.pop_back()
		var removed_page: Control = removed_entry.get("page", null) as Control
		if removed_page != null:
			_detach_or_free_page(removed_page)

		_stacks[_current_tab_id] = stack
		_show_current_page()
		return

	if _tab_history.size() > 1:
		_tab_history.remove_at(_tab_history.size() - 1)
		_current_tab_id = _tab_history[_tab_history.size() - 1]
		_show_current_page()
		tab_changed.emit(_current_tab_id)
		return

	back_pressed.emit()


func get_current_tab_id() -> String:
	return _current_tab_id


func get_current_route_id() -> String:
	var entry: Dictionary = _get_current_entry()
	return String(entry.get("route_id", ""))


func _ensure_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(320.0, 560.0)

	_root = get_node_or_null(_node_path(ROOT_NAME)) as PanelContainer
	if _root == null:
		_root = PanelContainer.new()
		_root.name = ROOT_NAME
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_root)

	_layout = _root.get_node_or_null(_node_path(LAYOUT_NAME)) as VBoxContainer
	if _layout == null:
		_layout = VBoxContainer.new()
		_layout.name = LAYOUT_NAME
		_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_layout.add_theme_constant_override("separation", 0)
		_root.add_child(_layout)

	_app_bar = _layout.get_node_or_null(_node_path(APP_BAR_NAME)) as PanelContainer
	if _app_bar == null:
		_app_bar = PanelContainer.new()
		_app_bar.name = APP_BAR_NAME
		_app_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_layout.add_child(_app_bar)

	var app_margin: MarginContainer = _app_bar.get_node_or_null(^"Margin") as MarginContainer
	if app_margin == null:
		app_margin = MarginContainer.new()
		app_margin.name = "Margin"
		app_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app_margin.add_theme_constant_override("margin_left", 12)
		app_margin.add_theme_constant_override("margin_top", 8)
		app_margin.add_theme_constant_override("margin_right", 12)
		app_margin.add_theme_constant_override("margin_bottom", 8)
		_app_bar.add_child(app_margin)

	var app_row: HBoxContainer = app_margin.get_node_or_null(_node_path(APP_BAR_ROW_NAME)) as HBoxContainer
	if app_row == null:
		app_row = HBoxContainer.new()
		app_row.name = APP_BAR_ROW_NAME
		app_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		app_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_row.alignment = BoxContainer.ALIGNMENT_CENTER
		app_row.add_theme_constant_override("separation", 10)
		app_margin.add_child(app_row)

	_back_button = app_row.get_node_or_null(_node_path(BACK_BUTTON_NAME)) as Button
	if _back_button == null:
		_back_button = Button.new()
		_back_button.name = BACK_BUTTON_NAME
		_back_button.text = "‹"
		_back_button.focus_mode = Control.FOCUS_NONE
		_back_button.custom_minimum_size = Vector2(42.0, 42.0)
		app_row.add_child(_back_button)

	var title_stack: VBoxContainer = app_row.get_node_or_null(_node_path(TITLE_STACK_NAME)) as VBoxContainer
	if title_stack == null:
		title_stack = VBoxContainer.new()
		title_stack.name = TITLE_STACK_NAME
		title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_stack.add_theme_constant_override("separation", 0)
		app_row.add_child(title_stack)

	_title_label = title_stack.get_node_or_null(_node_path(TITLE_LABEL_NAME)) as Label
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = TITLE_LABEL_NAME
		_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_stack.add_child(_title_label)

	_subtitle_label = title_stack.get_node_or_null(_node_path(SUBTITLE_LABEL_NAME)) as Label
	if _subtitle_label == null:
		_subtitle_label = Label.new()
		_subtitle_label.name = SUBTITLE_LABEL_NAME
		_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_stack.add_child(_subtitle_label)

	_action_bar = app_row.get_node_or_null(_node_path(ACTION_BAR_NAME)) as HBoxContainer
	if _action_bar == null:
		_action_bar = HBoxContainer.new()
		_action_bar.name = ACTION_BAR_NAME
		_action_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
		_action_bar.add_theme_constant_override("separation", 8)
		app_row.add_child(_action_bar)

	_content_panel = _layout.get_node_or_null(_node_path(CONTENT_PANEL_NAME)) as PanelContainer
	if _content_panel == null:
		_content_panel = PanelContainer.new()
		_content_panel.name = CONTENT_PANEL_NAME
		_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_layout.add_child(_content_panel)

	_content_host = _content_panel.get_node_or_null(_node_path(CONTENT_HOST_NAME)) as Control
	if _content_host == null:
		_content_host = Control.new()
		_content_host.name = CONTENT_HOST_NAME
		_content_host.clip_contents = true
		_content_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_content_panel.add_child(_content_host)

	_bottom_bar = _layout.get_node_or_null(_node_path(BOTTOM_BAR_NAME)) as PanelContainer
	if _bottom_bar == null:
		_bottom_bar = PanelContainer.new()
		_bottom_bar.name = BOTTOM_BAR_NAME
		_bottom_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_layout.add_child(_bottom_bar)

	var bottom_margin: MarginContainer = _bottom_bar.get_node_or_null(^"Margin") as MarginContainer
	if bottom_margin == null:
		bottom_margin = MarginContainer.new()
		bottom_margin.name = "Margin"
		bottom_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bottom_margin.add_theme_constant_override("margin_left", 10)
		bottom_margin.add_theme_constant_override("margin_top", 8)
		bottom_margin.add_theme_constant_override("margin_right", 10)
		bottom_margin.add_theme_constant_override("margin_bottom", 8)
		_bottom_bar.add_child(bottom_margin)

	_bottom_row = bottom_margin.get_node_or_null(_node_path(BOTTOM_ROW_NAME)) as HBoxContainer
	if _bottom_row == null:
		_bottom_row = HBoxContainer.new()
		_bottom_row.name = BOTTOM_ROW_NAME
		_bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_bottom_row.add_theme_constant_override("separation", 8)
		bottom_margin.add_child(_bottom_row)

	if not _back_button.pressed.is_connected(_on_back_button_pressed):
		_back_button.pressed.connect(_on_back_button_pressed)


func _rebuild_bottom_nav() -> void:
	_ensure_ui()

	for child: Node in _bottom_row.get_children():
		_bottom_row.remove_child(child)
		child.queue_free()

	_bottom_buttons.clear()

	for tab_spec: Dictionary in _tabs:
		var tab_id: String = String(tab_spec.get("id", "")).strip_edges()
		var title: String = String(tab_spec.get("title", tab_id.capitalize())).strip_edges()
		var icon_path: String = String(tab_spec.get("icon_path", "")).strip_edges()
		var icon_texture: Texture2D = _texture_from_variant(tab_spec.get("icon", null))

		var button: Button = Button.new()
		button.name = "%sTabButton" % tab_id.capitalize()
		button.text = ""
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.pressed.connect(_on_tab_button_pressed.bind(tab_id))

		_apply_icon_only_button(button, icon_path, title, true, icon_texture, tab_icon_max_width)

		_bottom_row.add_child(button)
		_bottom_buttons[tab_id] = button

	_refresh_styles()


func _show_current_page() -> void:
	_ensure_ui()

	var entry: Dictionary = _get_current_entry()
	var page: Control = entry.get("page", null) as Control

	_clear_content_host()

	if page != null:
		if page.get_parent() != null:
			page.get_parent().remove_child(page)

		_content_host.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_title_label.text = String(entry.get("title", ""))
	_subtitle_label.text = String(entry.get("subtitle", ""))

	_refresh_nav_state()

	page_changed.emit(
		_current_tab_id,
		String(entry.get("route_id", "")),
		String(entry.get("title", ""))
	)


func _refresh_nav_state() -> void:
	if _back_button != null:
		_back_button.visible = can_go_back()
		_back_button.disabled = not can_go_back()

	for tab_key: Variant in _bottom_buttons.keys():
		var tab_id: String = String(tab_key)
		var button: Button = _bottom_buttons.get(tab_id, null) as Button
		if button != null:
			button.button_pressed = tab_id == _current_tab_id


func _refresh_layout() -> void:
	if _app_bar != null:
		_app_bar.custom_minimum_size = Vector2(0.0, app_bar_height)

	if _bottom_bar != null:
		_bottom_bar.custom_minimum_size = Vector2(0.0, bottom_bar_height)

	queue_redraw()


func _refresh_styles() -> void:
	if _root == null:
		return

	_root.add_theme_stylebox_override("panel", _make_style(background_color, background_color, 0.0, 0.0, 0.0))

	if _app_bar != null:
		_app_bar.add_theme_stylebox_override("panel", _make_style(app_bar_color, border_color, 0.0, 1.0, 0.0))

	if _bottom_bar != null:
		_bottom_bar.add_theme_stylebox_override("panel", _make_style(bottom_bar_color, border_color, 0.0, 1.0, 0.0))

	if _content_panel != null:
		_content_panel.add_theme_stylebox_override("panel", _make_style(content_color, content_color, 0.0, 0.0, 0.0))

	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 18)
		_title_label.add_theme_color_override("font_color", text_color)

	if _subtitle_label != null:
		_subtitle_label.add_theme_font_size_override("font_size", 12)
		_subtitle_label.add_theme_color_override("font_color", muted_text_color)

	if _back_button != null:
		_apply_icon_only_button(_back_button, back_button_icon_path, "‹", true, null, toolbar_icon_max_width)
		_style_toolbar_button(_back_button)

	if _action_bar != null:
		for child: Node in _action_bar.get_children():
			var button: Button = child as Button
			if button != null:
				_style_toolbar_button(button)

	for button_value: Variant in _bottom_buttons.values():
		var tab_button: Button = button_value as Button
		if tab_button != null:
			_style_tab_button(tab_button)

	queue_redraw()


func _refresh_icons() -> void:
	if _back_button != null:
		_apply_icon_only_button(_back_button, back_button_icon_path, "‹", true, null, toolbar_icon_max_width)
		_style_toolbar_button(_back_button)

	if _action_bar != null:
		for child: Node in _action_bar.get_children():
			var action_button: Button = child as Button
			if action_button != null:
				_style_toolbar_button(action_button)

	for tab_value: Variant in _tabs:
		if not (tab_value is Dictionary):
			continue

		var tab_spec: Dictionary = tab_value
		var tab_id: String = String(tab_spec.get("id", ""))
		var tab_button: Button = _bottom_buttons.get(tab_id, null) as Button
		if tab_button == null:
			continue

		_apply_icon_only_button(
			tab_button,
			String(tab_spec.get("icon_path", "")),
			String(tab_spec.get("title", tab_id.capitalize())),
			true,
			_texture_from_variant(tab_spec.get("icon", null)),
			tab_icon_max_width
		)
		_style_tab_button(tab_button)

	queue_redraw()


func _style_toolbar_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_style(elevated_color, border_color, 12.0, 1.0, 0.0))
	button.add_theme_stylebox_override("hover", _make_style(elevated_color.lightened(0.08), border_color.lightened(0.1), 12.0, 1.0, 0.0))
	button.add_theme_stylebox_override("pressed", _make_style(accent_color.darkened(0.15), accent_color, 12.0, 1.0, 0.0))

	var has_icon: bool = button.icon != null
	var toolbar_font_color: Color = Color.TRANSPARENT if has_icon else text_color
	var toolbar_font_size: int = 1 if has_icon else 22

	button.add_theme_color_override("font_color", toolbar_font_color)
	button.add_theme_color_override("font_pressed_color", toolbar_font_color)
	button.add_theme_color_override("font_hover_color", toolbar_font_color)
	button.add_theme_color_override("font_disabled_color", toolbar_font_color.darkened(0.35))
	button.add_theme_color_override("icon_normal_color", text_color)
	button.add_theme_color_override("icon_hover_color", text_color)
	button.add_theme_color_override("icon_pressed_color", text_color)
	button.add_theme_color_override("icon_disabled_color", muted_text_color.darkened(0.35))

	button.add_theme_font_size_override("font_size", toolbar_font_size)

func _style_tab_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_style(bottom_bar_color, bottom_bar_color, 16.0, 0.0, 10.0))
	button.add_theme_stylebox_override("hover", _make_style(elevated_color, elevated_color, 16.0, 0.0, 10.0))
	button.add_theme_stylebox_override("pressed", _make_style(accent_color.darkened(0.15), accent_color.darkened(0.15), 16.0, 0.0, 10.0))
	button.add_theme_stylebox_override("focus", _make_style(elevated_color, accent_color, 16.0, 1.0, 10.0))

	var has_icon: bool = button.icon != null
	var tab_font_color: Color = Color.TRANSPARENT if has_icon else muted_text_color
	var tab_font_pressed_color: Color = Color.TRANSPARENT if has_icon else text_color
	var tab_font_size: int = 1 if has_icon else 12

	button.add_theme_color_override("font_color", tab_font_color)
	button.add_theme_color_override("font_pressed_color", tab_font_pressed_color)
	button.add_theme_color_override("font_hover_color", tab_font_pressed_color)
	button.add_theme_color_override("font_focus_color", tab_font_pressed_color)
	button.add_theme_color_override("icon_normal_color", muted_text_color)
	button.add_theme_color_override("icon_hover_color", text_color)
	button.add_theme_color_override("icon_pressed_color", text_color)
	button.add_theme_color_override("icon_focus_color", text_color)

	button.add_theme_font_size_override("font_size", tab_font_size)

func _make_entry(route_id: String, title: String, subtitle: String, page: Control) -> Dictionary:
	return {
		"route_id": route_id.strip_edges(),
		"title": title.strip_edges(),
		"subtitle": subtitle.strip_edges(),
		"page": page
	}


func _get_current_entry() -> Dictionary:
	var stack: Array = _get_stack(_current_tab_id)
	if stack.is_empty():
		return {}

	var entry_value: Variant = stack[stack.size() - 1]
	if entry_value is Dictionary:
		return entry_value

	return {}


func _get_stack(tab_id: String) -> Array:
	var stack_value: Variant = _stacks.get(tab_id, [])
	if stack_value is Array:
		return stack_value
	return []


func _clear_stack(tab_id: String) -> void:
	var stack: Array = _get_stack(tab_id)
	for entry_value: Variant in stack:
		if not (entry_value is Dictionary):
			continue

		var entry: Dictionary = entry_value
		var page: Control = entry.get("page", null) as Control
		if page != null:
			_detach_or_free_page(page)

	stack.clear()
	_stacks[tab_id] = stack


func _clear_content_host() -> void:
	if _content_host == null:
		return

	for child: Node in _content_host.get_children():
		_content_host.remove_child(child)


func _detach_or_free_page(page: Control) -> void:
	if page.get_parent() != null:
		page.get_parent().remove_child(page)

	if not page.is_queued_for_deletion():
		page.queue_free()


func _has_tab(tab_id: String) -> bool:
	for tab_spec: Dictionary in _tabs:
		if String(tab_spec.get("id", "")) == tab_id:
			return true
	return false


func _on_back_button_pressed() -> void:
	go_back()


func _on_tab_button_pressed(tab_id: String) -> void:
	select_tab(tab_id, true)


func _on_action_button_pressed(action_id: String) -> void:
	action_pressed.emit(action_id)


func _make_style(fill: Color, border: Color, radius: float, border_width: float, content_padding: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = int(border_width)
	style.border_width_top = int(border_width)
	style.border_width_right = int(border_width)
	style.border_width_bottom = int(border_width)
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.content_margin_left = content_padding
	style.content_margin_top = content_padding
	style.content_margin_right = content_padding
	style.content_margin_bottom = content_padding
	return style


func _node_path(node_name: StringName) -> NodePath:
	return NodePath(String(node_name))


func _apply_icon_only_button(
	button: Button,
	icon_path: String,
	fallback_text: String,
	icon_expand: bool = true,
	icon_texture: Texture2D = null,
	max_width: int = 20
) -> void:
	var clean_fallback_text: String = fallback_text.strip_edges()
	var texture: Texture2D = icon_texture

	if texture == null:
		texture = _load_texture(icon_path)

	button.tooltip_text = clean_fallback_text
	button.expand_icon = icon_expand
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", max_width)
	button.icon = texture

	if texture == null:
		button.text = clean_fallback_text
	else:
		button.text = ""


func _load_texture(icon_path: String) -> Texture2D:
	var clean_icon_path: String = icon_path.strip_edges()
	if clean_icon_path.is_empty():
		return null

	if not ResourceLoader.exists(clean_icon_path):
		push_warning("Navigation icon does not exist: %s" % clean_icon_path)
		return null

	var resource: Resource = ResourceLoader.load(clean_icon_path)
	var texture: Texture2D = resource as Texture2D
	if texture == null:
		push_warning("Navigation icon is not a Texture2D: %s" % clean_icon_path)
		return null

	return texture


func _texture_from_variant(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D

	if value is String:
		return _load_texture(String(value))

	return null
