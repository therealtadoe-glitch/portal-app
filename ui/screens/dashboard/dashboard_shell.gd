@tool
class_name DashboardShell
extends Control

signal sign_out_requested
signal refresh_requested

const ROOT_NAME: StringName = &"Root"
const PAGE_NAME: StringName = &"Page"
const HEADER_NAME: StringName = &"Header"
const TITLE_NAME: StringName = &"Title"
const SUBTITLE_NAME: StringName = &"Subtitle"
const REFRESH_BUTTON_NAME: StringName = &"RefreshButton"
const SIGN_OUT_BUTTON_NAME: StringName = &"SignOutButton"
const CARDS_NAME: StringName = &"Cards"

@export_group("Colors")
@export var background_color: Color = Color("10131a"):
	set(value):
		background_color = value
		_refresh_styles()
@export var surface_color: Color = Color("171c26"):
	set(value):
		surface_color = value
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

var _profile: Profile
var _current_organization: Organization
var _organizations: Array[Organization] = []

var _root: PanelContainer
var _page: VBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _refresh_button: Button
var _sign_out_button: Button
var _cards: VBoxContainer


func _ready() -> void:
	_ensure_ui()
	_refresh_content()
	_refresh_styles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()


func set_state(state: AppState) -> void:
	if state == null:
		_profile = null
		_current_organization = null
		_organizations = []
	else:
		_profile = state.profile
		_current_organization = state.current_organization
		_organizations = state.organizations.duplicate()

	_refresh_content()
	_refresh_styles()


func _ensure_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(320.0, 560.0)

	_root = get_node_or_null(_node_path(ROOT_NAME)) as PanelContainer
	if _root == null:
		_root = PanelContainer.new()
		_root.name = ROOT_NAME
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_root)

	var safe_margin: MarginContainer = _root.get_node_or_null(^"SafeMargin") as MarginContainer
	if safe_margin == null:
		safe_margin = MarginContainer.new()
		safe_margin.name = "SafeMargin"
		safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		safe_margin.add_theme_constant_override("margin_left", 18)
		safe_margin.add_theme_constant_override("margin_top", 18)
		safe_margin.add_theme_constant_override("margin_right", 18)
		safe_margin.add_theme_constant_override("margin_bottom", 18)
		_root.add_child(safe_margin)

	var scroll: ScrollContainer = safe_margin.get_node_or_null(^"Scroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		safe_margin.add_child(scroll)

	_page = scroll.get_node_or_null(_node_path(PAGE_NAME)) as VBoxContainer
	if _page == null:
		_page = VBoxContainer.new()
		_page.name = PAGE_NAME
		_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_page.add_theme_constant_override("separation", 16)
		scroll.add_child(_page)

	var header: VBoxContainer = _page.get_node_or_null(_node_path(HEADER_NAME)) as VBoxContainer
	if header == null:
		header = VBoxContainer.new()
		header.name = HEADER_NAME
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_theme_constant_override("separation", 8)
		_page.add_child(header)

	_title_label = header.get_node_or_null(_node_path(TITLE_NAME)) as Label
	if _title_label == null:
		_title_label = Label.new()
		_title_label.name = TITLE_NAME
		_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(_title_label)

	_subtitle_label = header.get_node_or_null(_node_path(SUBTITLE_NAME)) as Label
	if _subtitle_label == null:
		_subtitle_label = Label.new()
		_subtitle_label.name = SUBTITLE_NAME
		_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(_subtitle_label)

	var actions: HBoxContainer = header.get_node_or_null(^"Actions") as HBoxContainer
	if actions == null:
		actions = HBoxContainer.new()
		actions.name = "Actions"
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_theme_constant_override("separation", 10)
		header.add_child(actions)

	_refresh_button = actions.get_node_or_null(_node_path(REFRESH_BUTTON_NAME)) as Button
	if _refresh_button == null:
		_refresh_button = Button.new()
		_refresh_button.name = REFRESH_BUTTON_NAME
		_refresh_button.custom_minimum_size = Vector2(0.0, 42.0)
		_refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(_refresh_button)

	_sign_out_button = actions.get_node_or_null(_node_path(SIGN_OUT_BUTTON_NAME)) as Button
	if _sign_out_button == null:
		_sign_out_button = Button.new()
		_sign_out_button.name = SIGN_OUT_BUTTON_NAME
		_sign_out_button.custom_minimum_size = Vector2(0.0, 42.0)
		_sign_out_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(_sign_out_button)

	_cards = _page.get_node_or_null(_node_path(CARDS_NAME)) as VBoxContainer
	if _cards == null:
		_cards = VBoxContainer.new()
		_cards.name = CARDS_NAME
		_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cards.add_theme_constant_override("separation", 12)
		_page.add_child(_cards)

	if not _refresh_button.pressed.is_connected(_on_refresh_pressed):
		_refresh_button.pressed.connect(_on_refresh_pressed)
	if not _sign_out_button.pressed.is_connected(_on_sign_out_pressed):
		_sign_out_button.pressed.connect(_on_sign_out_pressed)


func _refresh_content() -> void:
	if _title_label == null:
		return

	var workspace_name: String = "Workspace"
	var workspace_slug: String = "No slug"
	if _current_organization != null:
		workspace_name = _current_organization.name
		workspace_slug = _current_organization.slug

	var display_name: String = "Employee"
	var email: String = ""
	if _profile != null:
		display_name = _profile.display_name
		email = _profile.email

	_title_label.text = workspace_name
	if email.strip_edges().is_empty():
		_subtitle_label.text = "Signed in as %s" % display_name
	else:
		_subtitle_label.text = "Signed in as %s • %s" % [display_name, email]

	_refresh_button.text = "Refresh"
	_sign_out_button.text = "Sign out"
	_rebuild_cards(workspace_name, workspace_slug, display_name)


func _rebuild_cards(workspace_name: String, workspace_slug: String, display_name: String) -> void:
	if _cards == null:
		return

	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()

	_cards.add_child(_make_info_card("Workspace", workspace_name, "Slug: %s" % workspace_slug))
	_cards.add_child(_make_info_card("Profile", display_name, _profile_summary()))
	_cards.add_child(_make_info_card("Organizations", str(_organizations.size()), "Visible workspaces for this account."))
	_cards.add_child(_make_info_card("Next module", "Employees", "Build member invitations, departments, and roles next."))
	_cards.add_child(_make_info_card("Work queue", "Tasks", "Projects and task boards will attach to this workspace."))


func _make_info_card(title: String, value: String, detail: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 112.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_style(surface_color, border_color, 16.0, 1.0, 18.0))

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", muted_text_color)
	content.add_child(title_label)

	var value_label: Label = Label.new()
	value_label.text = value
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", text_color)
	content.add_child(value_label)

	var detail_label: Label = Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", muted_text_color)
	content.add_child(detail_label)

	return panel


func _profile_summary() -> String:
	if _profile == null:
		return "No profile loaded."

	var details: Array[String] = []
	if not _profile.job_title.strip_edges().is_empty():
		details.append(_profile.job_title)
	if not _profile.timezone.strip_edges().is_empty():
		details.append("Timezone: %s" % _profile.timezone)

	if details.is_empty():
		return "Profile loaded."

	return " • ".join(details)


func _refresh_styles() -> void:
	if _root == null:
		return

	_root.add_theme_stylebox_override("panel", _make_style(background_color, background_color, 0.0, 0.0, 0.0))

	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 30)
		_title_label.add_theme_color_override("font_color", text_color)
	if _subtitle_label != null:
		_subtitle_label.add_theme_font_size_override("font_size", 14)
		_subtitle_label.add_theme_color_override("font_color", muted_text_color)

	if _refresh_button != null:
		_refresh_button.add_theme_stylebox_override("normal", _make_style(elevated_color, border_color, 12.0, 1.0, 0.0))
		_refresh_button.add_theme_stylebox_override("hover", _make_style(elevated_color.lightened(0.05), border_color, 12.0, 1.0, 0.0))
		_refresh_button.add_theme_color_override("font_color", text_color)

	if _sign_out_button != null:
		_sign_out_button.add_theme_stylebox_override("normal", _make_style(accent_color, accent_color, 12.0, 0.0, 0.0))
		_sign_out_button.add_theme_stylebox_override("hover", _make_style(accent_color.lightened(0.08), accent_color.lightened(0.08), 12.0, 0.0, 0.0))
		_sign_out_button.add_theme_color_override("font_color", Color.WHITE)


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


func _on_refresh_pressed() -> void:
	refresh_requested.emit()


func _on_sign_out_pressed() -> void:
	sign_out_requested.emit()


func _node_path(node_name: StringName) -> NodePath:
	return NodePath(String(node_name))
