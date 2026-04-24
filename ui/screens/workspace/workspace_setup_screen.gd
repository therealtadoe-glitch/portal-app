@tool
class_name WorkspaceSetupScreen
extends Control

signal workspace_created(organization: Organization)
signal sign_out_requested

const ROOT_NAME: StringName = &"Root"
const CARD_NAME: StringName = &"WorkspaceCard"
const TITLE_NAME: StringName = &"Title"
const SUBTITLE_NAME: StringName = &"Subtitle"
const ORG_NAME_FIELD_NAME: StringName = &"OrganizationNameField"
const CREATE_BUTTON_NAME: StringName = &"CreateButton"
const SIGN_OUT_BUTTON_NAME: StringName = &"SignOutButton"
const STATUS_LABEL_NAME: StringName = &"StatusLabel"

@export var organization_repository_path: NodePath = ^"/root/OrganizationRepository"

@export_group("Colors")
@export var background_color: Color = Color("10131a"):
	set(value):
		background_color = value
		_refresh_styles()
@export var card_color: Color = Color("171c26"):
	set(value):
		card_color = value
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
var _is_busy: bool = false

var _root: PanelContainer
var _card: VBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _org_name_field: LineEdit
var _create_button: Button
var _sign_out_button: Button
var _status_label: Label


func _ready() -> void:
	_ensure_ui()
	_refresh_styles()
	_refresh_content()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()


func set_profile(profile: Profile) -> void:
	_profile = profile
	_refresh_content()


func set_status(message: String, is_error: bool = false) -> void:
	_ensure_ui()
	_show_status(message, is_error)


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

	var center: CenterContainer = _root.get_node_or_null(^"Center") as CenterContainer
	if center == null:
		center = CenterContainer.new()
		center.name = "Center"
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root.add_child(center)

	var margin: MarginContainer = center.get_node_or_null(^"Margin") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "Margin"
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 20)
		center.add_child(margin)

	var card_panel: PanelContainer = margin.get_node_or_null(_node_path(CARD_NAME)) as PanelContainer
	if card_panel == null:
		card_panel = PanelContainer.new()
		card_panel.name = CARD_NAME
		card_panel.custom_minimum_size = Vector2(340.0, 0.0)
		card_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		margin.add_child(card_panel)

	_card = card_panel.get_node_or_null(^"Content") as VBoxContainer
	if _card == null:
		_card = VBoxContainer.new()
		_card.name = "Content"
		_card.add_theme_constant_override("separation", 12)
		card_panel.add_child(_card)

	_title_label = _get_or_create_label(TITLE_NAME, 26, true)
	_subtitle_label = _get_or_create_label(SUBTITLE_NAME, 14, false)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_org_name_field = _get_or_create_line_edit(ORG_NAME_FIELD_NAME, "Company or workspace name")
	if not _org_name_field.text_submitted.is_connected(_on_organization_submitted):
		_org_name_field.text_submitted.connect(_on_organization_submitted)

	_create_button = _get_or_create_button(CREATE_BUTTON_NAME)
	_sign_out_button = _get_or_create_button(SIGN_OUT_BUTTON_NAME)
	_sign_out_button.flat = true

	_status_label = _get_or_create_label(STATUS_LABEL_NAME, 13, false)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not _create_button.pressed.is_connected(_on_create_pressed):
		_create_button.pressed.connect(_on_create_pressed)
	if not _sign_out_button.pressed.is_connected(_on_sign_out_pressed):
		_sign_out_button.pressed.connect(_on_sign_out_pressed)


func _get_or_create_label(node_name: StringName, font_size: int, bold: bool) -> Label:
	var label: Label = _card.get_node_or_null(_node_path(node_name)) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card.add_child(label)

	label.add_theme_font_size_override("font_size", font_size)
	if bold:
		label.add_theme_color_override("font_color", text_color)
	else:
		label.add_theme_color_override("font_color", muted_text_color)
	return label


func _get_or_create_line_edit(node_name: StringName, placeholder: String) -> LineEdit:
	var field: LineEdit = _card.get_node_or_null(_node_path(node_name)) as LineEdit
	if field == null:
		field = LineEdit.new()
		field.name = node_name
		field.custom_minimum_size = Vector2(0.0, 46.0)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card.add_child(field)

	field.placeholder_text = placeholder
	field.clear_button_enabled = true
	return field


func _get_or_create_button(node_name: StringName) -> Button:
	var button: Button = _card.get_node_or_null(_node_path(node_name)) as Button
	if button == null:
		button = Button.new()
		button.name = node_name
		button.custom_minimum_size = Vector2(0.0, 46.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_card.add_child(button)
	return button


func _refresh_content() -> void:
	if _title_label == null:
		return

	_title_label.text = "Create workspace"
	if _profile != null and not _profile.display_name.strip_edges().is_empty():
		_subtitle_label.text = "Welcome, %s. Create your first organization to continue." % _profile.display_name
	else:
		_subtitle_label.text = "Create your first organization to continue."

	_create_button.text = "Create workspace"
	_sign_out_button.text = "Sign out"
	_status_label.text = ""


func _refresh_styles() -> void:
	if _root == null:
		return

	_root.add_theme_stylebox_override("panel", _make_style(background_color, background_color, 0.0, 0.0, 0.0))

	var card_path: NodePath = NodePath("Center/Margin/%s" % String(CARD_NAME))
	var card_panel: PanelContainer = _root.get_node_or_null(card_path) as PanelContainer
	if card_panel != null:
		card_panel.add_theme_stylebox_override("panel", _make_style(card_color, border_color, 18.0, 1.0, 24.0))

	if _title_label != null:
		_title_label.add_theme_color_override("font_color", text_color)
	if _subtitle_label != null:
		_subtitle_label.add_theme_color_override("font_color", muted_text_color)
	if _status_label != null:
		_status_label.add_theme_color_override("font_color", muted_text_color)

	if _org_name_field != null:
		_org_name_field.add_theme_stylebox_override("normal", _make_style(Color("0f141d"), border_color, 12.0, 1.0, 0.0))
		_org_name_field.add_theme_stylebox_override("focus", _make_style(Color("0f141d"), accent_color, 12.0, 1.5, 0.0))
		_org_name_field.add_theme_color_override("font_color", text_color)
		_org_name_field.add_theme_color_override("font_placeholder_color", muted_text_color.darkened(0.15))

	if _create_button != null:
		_create_button.add_theme_stylebox_override("normal", _make_style(accent_color, accent_color, 12.0, 0.0, 0.0))
		_create_button.add_theme_stylebox_override("hover", _make_style(accent_color.lightened(0.08), accent_color.lightened(0.08), 12.0, 0.0, 0.0))
		_create_button.add_theme_stylebox_override("pressed", _make_style(accent_color.darkened(0.1), accent_color.darkened(0.1), 12.0, 0.0, 0.0))
		_create_button.add_theme_color_override("font_color", Color.WHITE)

	if _sign_out_button != null:
		_sign_out_button.add_theme_color_override("font_color", muted_text_color)


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


func _on_organization_submitted(_value: String) -> void:
	_on_create_pressed()


func _on_create_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var organization_name: String = _org_name_field.text.strip_edges()
	if organization_name.length() < 2:
		_show_status("Workspace name must be at least 2 characters.", true)
		_show_error_toast("Workspace name must be at least 2 characters.")
		return

	var repository: AppOrganizationRepository = get_node_or_null(organization_repository_path) as AppOrganizationRepository
	if repository == null:
		_show_status("OrganizationRepository autoload was not found.", true)
		_show_error_toast("OrganizationRepository autoload was not found.")
		return

	_set_busy(true)
	var result: SupabaseResult = await repository.create_organization(organization_name)
	_set_busy(false)

	if not result.ok:
		_show_status(result.error_message, true)
		_show_error_toast(result.error_message)
		return

	var organization_value: Variant = result.data
	if not (organization_value is Organization):
		_show_status("Created workspace response was not valid.", true)
		_show_error_toast("Created workspace response was not valid.")
		return

	_show_status("Workspace created.", false)
	_show_success_toast("Workspace created.")
	workspace_created.emit(organization_value)


func _on_sign_out_pressed() -> void:
	if _is_busy:
		return
	sign_out_requested.emit()


func _set_busy(value: bool) -> void:
	_is_busy = value
	_create_button.disabled = value
	_sign_out_button.disabled = value
	_org_name_field.editable = not value
	_create_button.text = "Creating..." if value else "Create workspace"


func _show_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	var color: Color = Color("ff6b6b") if is_error else muted_text_color
	_status_label.add_theme_color_override("font_color", color)


func _show_success_toast(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_success(message)


func _show_error_toast(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_error(message)


func _node_path(node_name: StringName) -> NodePath:
	return NodePath(String(node_name))
