@tool
class_name AuthScreen
extends Control

signal authenticated

const CARD_NAME: StringName = &"AuthCard"
const ROOT_NAME: StringName = &"Root"
const TITLE_NAME: StringName = &"Title"
const SUBTITLE_NAME: StringName = &"Subtitle"
const DISPLAY_NAME_FIELD_NAME: StringName = &"DisplayNameField"
const EMAIL_FIELD_NAME: StringName = &"EmailField"
const PASSWORD_FIELD_NAME: StringName = &"PasswordField"
const SUBMIT_BUTTON_NAME: StringName = &"SubmitButton"
const MODE_BUTTON_NAME: StringName = &"ModeButton"
const STATUS_LABEL_NAME: StringName = &"StatusLabel"

@export var client_path: NodePath = ^"/root/SupabaseClient"
@export var start_in_sign_up_mode: bool = false:
	set(value):
		start_in_sign_up_mode = value
		_is_sign_up_mode = value
		_refresh_content()

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

var _is_sign_up_mode: bool = false
var _is_busy: bool = false

var _root: PanelContainer
var _card: VBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _display_name_field: LineEdit
var _email_field: LineEdit
var _password_field: LineEdit
var _submit_button: Button
var _mode_button: Button
var _status_label: Label


func _ready() -> void:
	_is_sign_up_mode = start_in_sign_up_mode
	_ensure_ui()
	_refresh_styles()
	_refresh_content()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()


func set_status(message: String, is_error: bool = false) -> void:
	_ensure_ui()
	_show_status(message, is_error)


func clear_fields() -> void:
	_ensure_ui()
	_display_name_field.text = ""
	_email_field.text = ""
	_password_field.text = ""
	_show_status("", false)


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

	_display_name_field = _get_or_create_line_edit(DISPLAY_NAME_FIELD_NAME, "Display name")
	_email_field = _get_or_create_line_edit(EMAIL_FIELD_NAME, "Email")
	_email_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS

	_password_field = _get_or_create_line_edit(PASSWORD_FIELD_NAME, "Password")
	_password_field.secret = true
	_password_field.context_menu_enabled = false

	_submit_button = _get_or_create_button(SUBMIT_BUTTON_NAME)
	_mode_button = _get_or_create_button(MODE_BUTTON_NAME)
	_mode_button.flat = true

	_status_label = _get_or_create_label(STATUS_LABEL_NAME, 13, false)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not _submit_button.pressed.is_connected(_on_submit_pressed):
		_submit_button.pressed.connect(_on_submit_pressed)
	if not _mode_button.pressed.is_connected(_on_mode_pressed):
		_mode_button.pressed.connect(_on_mode_pressed)
	if not _password_field.text_submitted.is_connected(_on_password_submitted):
		_password_field.text_submitted.connect(_on_password_submitted)


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

	if _is_sign_up_mode:
		_title_label.text = "Create account"
		_subtitle_label.text = "Create your employee portal account, then create or join an organization."
		_submit_button.text = "Create account"
		_mode_button.text = "Already have an account? Sign in"
	else:
		_title_label.text = "Welcome back"
		_subtitle_label.text = "Sign in to continue to your workspace."
		_submit_button.text = "Sign in"
		_mode_button.text = "Need an account? Create one"

	_display_name_field.visible = _is_sign_up_mode
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

	if _submit_button != null:
		_submit_button.add_theme_stylebox_override("normal", _make_style(accent_color, accent_color, 12.0, 0.0, 0.0))
		_submit_button.add_theme_stylebox_override("hover", _make_style(accent_color.lightened(0.08), accent_color.lightened(0.08), 12.0, 0.0, 0.0))
		_submit_button.add_theme_stylebox_override("pressed", _make_style(accent_color.darkened(0.1), accent_color.darkened(0.1), 12.0, 0.0, 0.0))
		_submit_button.add_theme_color_override("font_color", Color.WHITE)

	var fields: Array[LineEdit] = []
	if _display_name_field != null:
		fields.append(_display_name_field)
	if _email_field != null:
		fields.append(_email_field)
	if _password_field != null:
		fields.append(_password_field)

	for field: LineEdit in fields:
		field.add_theme_stylebox_override("normal", _make_style(Color("0f141d"), border_color, 12.0, 1.0, 0.0))
		field.add_theme_stylebox_override("focus", _make_style(Color("0f141d"), accent_color, 12.0, 1.5, 0.0))
		field.add_theme_color_override("font_color", text_color)
		field.add_theme_color_override("font_placeholder_color", muted_text_color.darkened(0.15))


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


func _on_mode_pressed() -> void:
	if _is_busy:
		return
	_is_sign_up_mode = not _is_sign_up_mode
	_refresh_content()


func _on_password_submitted(_value: String) -> void:
	_on_submit_pressed()


func _on_submit_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var client: AppSupabaseClient = get_node_or_null(client_path) as AppSupabaseClient
	if client == null:
		_show_status("SupabaseClient autoload was not found.", true)
		return

	_set_busy(true)

	var result: SupabaseResult
	if _is_sign_up_mode:
		result = await client.sign_up(_email_field.text, _password_field.text, _display_name_field.text)
	else:
		result = await client.sign_in_with_password(_email_field.text, _password_field.text)

	_set_busy(false)

	if not result.ok:
		_show_status(result.error_message, true)
		_show_error_toast(result.error_message)
		return

	if client.has_session():
		_show_status("Authenticated.", false)
		_show_success_toast("Signed in successfully.")
		authenticated.emit()
		return

	_is_sign_up_mode = false
	_refresh_content()
	_show_status("Account created. Confirm your email, then sign in.", false)
	_show_info_toast("Confirm your email, then sign in.")


func _set_busy(value: bool) -> void:
	_is_busy = value
	_submit_button.disabled = value
	_mode_button.disabled = value
	_display_name_field.editable = not value
	_email_field.editable = not value
	_password_field.editable = not value
	if value:
		_submit_button.text = "Working..."
	else:
		_submit_button.text = "Create account" if _is_sign_up_mode else "Sign in"


func _show_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	var color: Color = Color("ff6b6b") if is_error else muted_text_color
	_status_label.add_theme_color_override("font_color", color)


func _show_success_toast(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_success(message)


func _show_info_toast(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_info(message)


func _show_error_toast(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_error(message)


func _node_path(node_name: StringName) -> NodePath:
	return NodePath(String(node_name))
