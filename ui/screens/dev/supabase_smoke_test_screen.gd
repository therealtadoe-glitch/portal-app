@tool
class_name SupabaseSmokeTestScreen
extends Control

const ROOT_NAME: StringName = &"SmokeTestRoot"
const CONTENT_NAME: StringName = &"Content"
const TITLE_NAME: StringName = &"TitleLabel"
const STATUS_NAME: StringName = &"StatusLabel"
const EMAIL_NAME: StringName = &"EmailField"
const PASSWORD_NAME: StringName = &"PasswordField"
const DISPLAY_NAME: StringName = &"DisplayNameField"
const ORG_NAME: StringName = &"OrganizationNameField"
const LOG_NAME: StringName = &"LogOutput"

@export var client_path: NodePath = ^"/root/SupabaseClient"
@export var profile_repository_path: NodePath = ^"/root/ProfileRepository"
@export var organization_repository_path: NodePath = ^"/root/OrganizationRepository"

@export var background_color: Color = Color("0b0f16"):
	set(value):
		background_color = value
		_refresh_styles()
@export var card_color: Color = Color("111827"):
	set(value):
		card_color = value
		_refresh_styles()
@export var border_color: Color = Color("263244"):
	set(value):
		border_color = value
		_refresh_styles()
@export var text_color: Color = Color("f7fafc"):
	set(value):
		text_color = value
		_refresh_styles()
@export var muted_text_color: Color = Color("aab4c4"):
	set(value):
		muted_text_color = value
		_refresh_styles()
@export var accent_color: Color = Color("4f8cff"):
	set(value):
		accent_color = value
		_refresh_styles()
@export var success_color: Color = Color("4ade80"):
	set(value):
		success_color = value
		_refresh_styles()
@export var error_color: Color = Color("ff6b6b"):
	set(value):
		error_color = value
		_refresh_styles()

var _root: PanelContainer
var _content: VBoxContainer
var _title_label: Label
var _status_label: Label
var _email_field: LineEdit
var _password_field: LineEdit
var _display_name_field: LineEdit
var _organization_name_field: LineEdit
var _log_output: RichTextLabel
var _sign_up_button: Button
var _sign_in_button: Button
var _fetch_profile_button: Button
var _update_profile_button: Button
var _create_organization_button: Button
var _list_organizations_button: Button
var _sign_out_button: Button
var _clear_log_button: Button
var _is_busy: bool = false

func _ready() -> void:
	_ensure_ui()
	_refresh_styles()
	_refresh_session_status()
	_connect_client_debug_signals()

	if not Engine.is_editor_hint():
		_write_log("Smoke test ready. Run tests top-to-bottom.", false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()

func _ensure_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(360.0, 640.0)

	_root = get_node_or_null(_node_path(ROOT_NAME)) as PanelContainer
	if _root == null:
		_root = PanelContainer.new()
		_root.name = ROOT_NAME
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_root)
		_assign_editor_owner(_root)

	var margin: MarginContainer = _root.get_node_or_null("Margin") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "Margin"
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_bottom", 18)
		_root.add_child(margin)
		_assign_editor_owner(margin)

	var scroll: ScrollContainer = margin.get_node_or_null("Scroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(scroll)
		_assign_editor_owner(scroll)

	_content = scroll.get_node_or_null(_node_path(CONTENT_NAME)) as VBoxContainer
	if _content == null:
		_content = VBoxContainer.new()
		_content.name = CONTENT_NAME
		_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_theme_constant_override("separation", 12)
		scroll.add_child(_content)
		_assign_editor_owner(_content)

	_title_label = _get_or_create_label(TITLE_NAME, "Supabase Smoke Test", 26, true)
	_status_label = _get_or_create_label(STATUS_NAME, "Session: checking...", 13, false)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_email_field = _get_or_create_line_edit(EMAIL_NAME, "Email")
	_email_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_password_field = _get_or_create_line_edit(PASSWORD_NAME, "Password, 8+ characters")
	_password_field.secret = true
	_password_field.context_menu_enabled = false
	_display_name_field = _get_or_create_line_edit(DISPLAY_NAME, "Display name")
	_organization_name_field = _get_or_create_line_edit(ORG_NAME, "Organization name")

	_ensure_default_input_values()

	_sign_up_button = _get_or_create_button(&"SignUpButton", "1. Sign up")
	_sign_in_button = _get_or_create_button(&"SignInButton", "2. Sign in")
	_fetch_profile_button = _get_or_create_button(&"FetchProfileButton", "3. Fetch profile")
	_update_profile_button = _get_or_create_button(&"UpdateProfileButton", "4. Update profile")
	_create_organization_button = _get_or_create_button(&"CreateOrganizationButton", "5. Create organization")
	_list_organizations_button = _get_or_create_button(&"ListOrganizationsButton", "6. List my organizations")
	_sign_out_button = _get_or_create_button(&"SignOutButton", "Sign out")
	_clear_log_button = _get_or_create_button(&"ClearLogButton", "Clear log")

	_log_output = _content.get_node_or_null(_node_path(LOG_NAME)) as RichTextLabel
	if _log_output == null:
		_log_output = RichTextLabel.new()
		_log_output.name = LOG_NAME
		_log_output.bbcode_enabled = true
		_log_output.fit_content = true
		_log_output.scroll_active = false
		_log_output.custom_minimum_size = Vector2(0.0, 260.0)
		_log_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(_log_output)
		_assign_editor_owner(_log_output)

	_connect_button(_sign_up_button, _on_sign_up_pressed)
	_connect_button(_sign_in_button, _on_sign_in_pressed)
	_connect_button(_fetch_profile_button, _on_fetch_profile_pressed)
	_connect_button(_update_profile_button, _on_update_profile_pressed)
	_connect_button(_create_organization_button, _on_create_organization_pressed)
	_connect_button(_list_organizations_button, _on_list_organizations_pressed)
	_connect_button(_sign_out_button, _on_sign_out_pressed)
	_connect_button(_clear_log_button, _on_clear_log_pressed)

func _assign_editor_owner(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null:
		node.owner = get_tree().edited_scene_root

func _node_path(node_name: StringName) -> NodePath:
	return NodePath(String(node_name))

func _get_or_create_label(node_name: StringName, label_text: String, font_size: int, is_title: bool) -> Label:
	var label: Label = _content.get_node_or_null(_node_path(node_name)) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(label)
		_assign_editor_owner(label)

	label.text = label_text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color if is_title else muted_text_color)
	return label

func _get_or_create_line_edit(node_name: StringName, placeholder: String) -> LineEdit:
	var field: LineEdit = _content.get_node_or_null(_node_path(node_name)) as LineEdit
	if field == null:
		field = LineEdit.new()
		field.name = node_name
		field.custom_minimum_size = Vector2(0.0, 46.0)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.clear_button_enabled = true
		_content.add_child(field)
		_assign_editor_owner(field)

	field.placeholder_text = placeholder
	return field

func _get_or_create_button(node_name: StringName, label_text: String) -> Button:
	var button: Button = _content.get_node_or_null(_node_path(node_name)) as Button
	if button == null:
		button = Button.new()
		button.name = node_name
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(button)
		_assign_editor_owner(button)

	button.text = label_text
	return button

func _connect_button(button: Button, callback: Callable) -> void:
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _ensure_default_input_values() -> void:
	if Engine.is_editor_hint():
		return

	var timestamp: int = int(Time.get_unix_time_from_system())
	if _display_name_field.text.strip_edges().is_empty():
		_display_name_field.text = "Dante Test"
	if _organization_name_field.text.strip_edges().is_empty():
		_organization_name_field.text = "Dante Test Org %d" % timestamp

func _refresh_styles() -> void:
	if _root == null:
		return

	_root.add_theme_stylebox_override("panel", _make_style(background_color, background_color, 0.0, 0, 0))

	if _content != null:
		_content.add_theme_constant_override("separation", 12)

	if _title_label != null:
		_title_label.add_theme_color_override("font_color", text_color)
	if _status_label != null:
		_status_label.add_theme_color_override("font_color", muted_text_color)

	var fields: Array[LineEdit] = []
	if _email_field != null:
		fields.append(_email_field)
	if _password_field != null:
		fields.append(_password_field)
	if _display_name_field != null:
		fields.append(_display_name_field)
	if _organization_name_field != null:
		fields.append(_organization_name_field)

	for field: LineEdit in fields:
		field.add_theme_stylebox_override("normal", _make_style(card_color, border_color, 12.0, 1, 0))
		field.add_theme_stylebox_override("focus", _make_style(card_color, accent_color, 12.0, 2, 0))
		field.add_theme_color_override("font_color", text_color)
		field.add_theme_color_override("font_placeholder_color", muted_text_color.darkened(0.18))

	var buttons: Array[Button] = []
	if _sign_up_button != null:
		buttons.append(_sign_up_button)
	if _sign_in_button != null:
		buttons.append(_sign_in_button)
	if _fetch_profile_button != null:
		buttons.append(_fetch_profile_button)
	if _update_profile_button != null:
		buttons.append(_update_profile_button)
	if _create_organization_button != null:
		buttons.append(_create_organization_button)
	if _list_organizations_button != null:
		buttons.append(_list_organizations_button)
	if _sign_out_button != null:
		buttons.append(_sign_out_button)
	if _clear_log_button != null:
		buttons.append(_clear_log_button)

	for button: Button in buttons:
		button.add_theme_stylebox_override("normal", _make_style(accent_color, accent_color, 12.0, 0, 0))
		button.add_theme_stylebox_override("hover", _make_style(accent_color.lightened(0.08), accent_color.lightened(0.08), 12.0, 0, 0))
		button.add_theme_stylebox_override("pressed", _make_style(accent_color.darkened(0.12), accent_color.darkened(0.12), 12.0, 0, 0))
		button.add_theme_stylebox_override("disabled", _make_style(border_color, border_color, 12.0, 0, 0))
		button.add_theme_color_override("font_color", Color.WHITE)

	if _log_output != null:
		_log_output.add_theme_stylebox_override("normal", _make_style(Color("05080d"), border_color, 14.0, 1, 14))
		_log_output.add_theme_color_override("default_color", muted_text_color)

func _make_style(fill: Color, border: Color, radius: float, border_width: int, content_padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.content_margin_left = content_padding
	style.content_margin_top = content_padding
	style.content_margin_right = content_padding
	style.content_margin_bottom = content_padding
	return style

func _connect_client_debug_signals() -> void:
	if Engine.is_editor_hint():
		return

	var client: AppSupabaseClient = _get_client()
	if client == null:
		_write_log("SupabaseClient autoload is missing.", true)
		#ToastManager.show_warning("SupabaseClient autoload is missing.")
		return

	if not client.session_changed.is_connected(_on_session_changed):
		client.session_changed.connect(_on_session_changed)
	if not client.request_started.is_connected(_on_request_started):
		client.request_started.connect(_on_request_started)
	if not client.request_finished.is_connected(_on_request_finished):
		client.request_finished.connect(_on_request_finished)

func _on_sign_up_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var client: AppSupabaseClient = _get_client()
	if client == null:
		_write_log("Cannot sign up: SupabaseClient autoload is missing.", true)
		#ToastManager.show_error("Cannot sign up: SupabaseClient autoload is missing.")
		return

	_set_busy(true)
	var result: SupabaseResult = await client.sign_up(
		_email_field.text,
		_password_field.text,
		_display_name_field.text
	)
	_set_busy(false)

	if result.ok:
		if client.has_session():
			_write_log("Sign up passed and session is active.", false)
			#ToastManager.show_success("Sign up passed and session is active.")
		else:
			_write_log("Sign up passed, but no session was returned. Confirm the email, then press Sign in.", false)
			#ToastManager.show_warning("Sign up passed, but no session was returned. Confirm the email, then press Sign in.")
	else:
		_write_result_failure("Sign up failed", result)
		#ToastManager.show_error("Sign up failed" + ": " + str(result))

	_refresh_session_status()

func _on_sign_in_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var client: AppSupabaseClient = _get_client()
	if client == null:
		_write_log("Cannot sign in: SupabaseClient autoload is missing.", true)
		#ToastManager.show_warning("Cannot sign in: SupabaseClient autoload is missing.")
		return

	_set_busy(true)
	var result: SupabaseResult = await client.sign_in_with_password(_email_field.text, _password_field.text)
	_set_busy(false)

	if result.ok:
		_write_log("Sign in passed. User ID: %s" % client.get_user_id(), false)
		#ToastManager.show_success("Sign in passed. User ID: %s" % client.get_user_id())
	else:
		_write_result_failure("Sign in failed", result)
		#ToastManager.show_error("Sign in failed" + ": " + str(result))

	_refresh_session_status()

func _on_fetch_profile_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var repository: AppProfileRepository = _get_profile_repository()
	if repository == null:
		_write_log("Cannot fetch profile: ProfileRepository autoload is missing.", true)
		#ToastManager.show_warning("Cannot fetch profile: ProfileRepository autoload is missing.")
		return

	_set_busy(true)
	var result: SupabaseResult = await repository.fetch_current_profile()
	_set_busy(false)

	if result.ok:
		var profile: Profile = result.data as Profile
		if profile == null:
			_write_log("Profile fetch returned an unexpected payload.", true)
			#ToastManager.show_info("Profile fetch returned an unexpected payload.")
			return
		_write_log("Profile loaded: %s / %s" % [profile.id, profile.display_name], false)
		#ToastManager.show_success("Profile loaded: %s / %s" % [profile.id, profile.display_name])
	else:
		_write_result_failure("Fetch profile failed", result)
		#ToastManager.show_error("Fetch profile failed" + ": " + str(result))

func _on_update_profile_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var repository: AppProfileRepository = _get_profile_repository()
	if repository == null:
		_write_log("Cannot update profile: ProfileRepository autoload is missing.", true)
		#ToastManager.show_warning("Cannot update profile: ProfileRepository autoload is missing.")
		return

	_set_busy(true)
	var fetch_result: SupabaseResult = await repository.fetch_current_profile()
	if not fetch_result.ok:
		_set_busy(false)
		_write_result_failure("Profile update prefetch failed", fetch_result)
		#ToastManager.show_error("Profile update prefetch failed" + ": " + str(fetch_result))
		return

	var profile: Profile = fetch_result.data as Profile
	if profile == null:
		_set_busy(false)
		_write_log("Profile update prefetch returned an unexpected payload.", true)
		#ToastManager.show_warning("Profile update prefetch returned an unexpected payload.")
		return

	profile.display_name = _display_name_field.text.strip_edges()
	if profile.display_name.is_empty():
		profile.display_name = "Employee"

	var update_result: SupabaseResult = await repository.update_current_profile(profile)
	_set_busy(false)

	if update_result.ok:
		var updated_profile: Profile = update_result.data as Profile
		if updated_profile == null:
			_write_log("Profile update returned an unexpected payload.", true)
			ToastManager.show_warning("Profile update returned an unexpected payload.")
			return
		_write_log("Profile updated: %s" % updated_profile.display_name, false)
		#ToastManager.show_success("Profile updated: %s" % updated_profile.display_name)
	else:
		_write_result_failure("Profile update failed", update_result)

func _on_create_organization_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var repository: AppOrganizationRepository = _get_organization_repository()
	if repository == null:
		_write_log("Cannot create organization: OrganizationRepository autoload is missing.", true)
		#ToastManager.show_error("Cannot create organization: OrganizationRepository autoload is missing.")
		return

	_set_busy(true)
	var result: SupabaseResult = await repository.create_organization(_organization_name_field.text)
	_set_busy(false)

	if result.ok:
		var organization: Organization = result.data as Organization
		if organization == null:
			_write_log("Organization create returned an unexpected payload.", true)
			#ToastManager.show_warning("Organization create returned an unexpected payload.")
			return
		_write_log("Organization created: %s / %s" % [organization.name, organization.id], false)
		#ToastManager.show_success("Organization created: %s / %s" % [organization.name, organization.id])
	else:
		_write_result_failure("Organization create failed", result)
		#ToastManager.show_error("Organization create failed: " + str(result))

func _on_list_organizations_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var repository: AppOrganizationRepository = _get_organization_repository()
	if repository == null:
		_write_log("Cannot list organizations: OrganizationRepository autoload is missing.", true)
		#ToastManager.show_warning("Cannot list organizations: OrganizationRepository autoload is missing.")
		return

	_set_busy(true)
	var result: SupabaseResult = await repository.list_my_organizations()
	_set_busy(false)

	if result.ok:
		var organizations: Array = result.as_array()
		_write_log("Organizations visible to current user: %d" % organizations.size(), false)
		#ToastManager.show_success("Organizations visible to current user: %d" % organizations.size())
		for item: Variant in organizations:
			if item is Organization:
				var organization: Organization = item
				_write_log("- %s [%s]" % [organization.name, organization.slug], false)
				#ToastManager.show_info("- %s [%s]" % [organization.name, organization.slug])
	else:
		_write_result_failure("List organizations failed", result)
		#ToastManager.show_error("List organizations failed" + ": " + str(result))

func _on_sign_out_pressed() -> void:
	if Engine.is_editor_hint() or _is_busy:
		return

	var client: AppSupabaseClient = _get_client()
	if client == null:
		_write_log("Cannot sign out: SupabaseClient autoload is missing.", true)
		#ToastManager.show_warning("Cannot sign out: SupabaseClient autoload is missing.")
		return

	_set_busy(true)
	var result: SupabaseResult = await client.sign_out()
	_set_busy(false)

	if result.ok:
		_write_log("Signed out.", false)
		#ToastManager.show_success("Signed out.")
	else:
		_write_result_failure("Remote sign out failed; local session was still cleared", result)
		#ToastManager.show_error("Remote sign out failed; local session was still cleared" + ": " + str(result))

	_refresh_session_status()

func _on_clear_log_pressed() -> void:
	if _log_output != null:
		_log_output.clear()

func _on_session_changed(_session: SupabaseSession) -> void:
	_refresh_session_status()

func _on_request_started(endpoint: String) -> void:
	_write_log("→ %s" % endpoint, false)
	#ToastManager.show_info("→ %s" % endpoint)

func _on_request_finished(endpoint: String, result: SupabaseResult) -> void:
	var prefix: String = "✓" if result.ok else "✕"
	_write_log("%s %s HTTP %d" % [prefix, endpoint, result.status_code], not result.ok)
	#ToastManager.show_warning("%s %s HTTP %d" % [prefix, endpoint, result.status_code])

func _refresh_session_status() -> void:
	if _status_label == null:
		return

	var client: AppSupabaseClient = _get_client()
	if client == null:
		_status_label.text = "Session: SupabaseClient autoload missing"
		_status_label.add_theme_color_override("font_color", error_color)
		return

	if not client.is_configured():
		_status_label.text = "Session: Supabase URL/key not configured"
		_status_label.add_theme_color_override("font_color", error_color)
		return

	if client.has_session():
		_status_label.text = "Session: authenticated as %s" % client.get_user_email()
		_status_label.add_theme_color_override("font_color", success_color)
	else:
		_status_label.text = "Session: not authenticated"
		_status_label.add_theme_color_override("font_color", muted_text_color)

func _set_busy(value: bool) -> void:
	_is_busy = value

	var buttons: Array[Button] = []
	if _sign_up_button != null:
		buttons.append(_sign_up_button)
	if _sign_in_button != null:
		buttons.append(_sign_in_button)
	if _fetch_profile_button != null:
		buttons.append(_fetch_profile_button)
	if _update_profile_button != null:
		buttons.append(_update_profile_button)
	if _create_organization_button != null:
		buttons.append(_create_organization_button)
	if _list_organizations_button != null:
		buttons.append(_list_organizations_button)
	if _sign_out_button != null:
		buttons.append(_sign_out_button)
	if _clear_log_button != null:
		buttons.append(_clear_log_button)

	for button: Button in buttons:
		button.disabled = value

	var fields: Array[LineEdit] = []
	if _email_field != null:
		fields.append(_email_field)
	if _password_field != null:
		fields.append(_password_field)
	if _display_name_field != null:
		fields.append(_display_name_field)
	if _organization_name_field != null:
		fields.append(_organization_name_field)

	for field: LineEdit in fields:
		field.editable = not value

func _write_result_failure(label: String, result: SupabaseResult) -> void:
	var message: String = "%s: %s" % [label, result.error_message]
	if result.status_code > 0:
		message += " [HTTP %d]" % result.status_code
	_write_log(message, true)

	var body: String = result.raw_body.strip_edges()
	if not body.is_empty():
		if body.length() > 700:
			body = body.substr(0, 700) + "..."
		_write_log(body, true)

func _write_log(message: String, is_error: bool) -> void:
	if _log_output == null:
		return

	var escaped_message: String = _escape_bbcode(message)
	var color_hex: String = error_color.to_html(false) if is_error else muted_text_color.to_html(false)
	_log_output.append_text("[color=#%s]%s[/color]\n" % [color_hex, escaped_message])

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "﹝").replace("]", "﹞")

func _get_client() -> AppSupabaseClient:
	return get_node_or_null(client_path) as AppSupabaseClient

func _get_profile_repository() -> AppProfileRepository:
	return get_node_or_null(profile_repository_path) as AppProfileRepository

func _get_organization_repository() -> AppOrganizationRepository:
	return get_node_or_null(organization_repository_path) as AppOrganizationRepository
