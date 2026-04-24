@tool
class_name AppRoot
extends Control

const ROOT_NAME: StringName = &"Root"
const HOST_NAME: StringName = &"ScreenHost"
const BOOT_CARD_NAME: StringName = &"BootCard"
const BOOT_LABEL_NAME: StringName = &"BootLabel"

@export var client_path: NodePath = ^"/root/SupabaseClient"
@export var profile_repository_path: NodePath = ^"/root/ProfileRepository"
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

var state: AppState = AppState.new()

var _root: PanelContainer
var _host: Control
var _is_bootstrapping: bool = false


func _ready() -> void:
	_ensure_ui()
	_refresh_styles()

	if Engine.is_editor_hint():
		_show_boot_screen("Employee portal app shell")
		return

	call_deferred("_bootstrap")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()


func _bootstrap() -> void:
	if _is_bootstrapping:
		return

	_is_bootstrapping = true
	_show_boot_screen("Loading your workspace...")

	var client: AppSupabaseClient = _get_client()
	if client == null:
		_is_bootstrapping = false
		_show_auth_screen("SupabaseClient autoload was not found.")
		return

	if not client.has_session():
		var session: SupabaseSession = client.get_session()
		if session != null and not session.refresh_token.strip_edges().is_empty():
			var refresh_result: SupabaseResult = await client.refresh_session()
			if not refresh_result.ok:
				_show_warning("Session expired. Sign in again.")
				_is_bootstrapping = false
				_show_auth_screen(refresh_result.error_message)
				return
		else:
			_is_bootstrapping = false
			_show_auth_screen()
			return

	await _load_authenticated_area()
	_is_bootstrapping = false


func _load_authenticated_area() -> void:
	_show_boot_screen("Syncing profile...")

	var profile_repository: AppProfileRepository = _get_profile_repository()
	if profile_repository == null:
		_show_error("ProfileRepository autoload was not found.")
		_show_auth_screen("ProfileRepository autoload was not found.")
		return

	var profile_result: SupabaseResult = await profile_repository.fetch_current_profile()
	if not profile_result.ok:
		_show_error(profile_result.error_message)
		_show_auth_screen(profile_result.error_message)
		return

	var profile_value: Variant = profile_result.data
	if not (profile_value is Profile):
		_show_error("Profile response was not a Profile resource.")
		_show_auth_screen("Profile response was not valid.")
		return

	state.profile = profile_value

	_show_boot_screen("Loading organizations...")

	var organization_repository: AppOrganizationRepository = _get_organization_repository()
	if organization_repository == null:
		_show_error("OrganizationRepository autoload was not found.")
		_show_workspace_setup_screen("OrganizationRepository autoload was not found.")
		return

	var organizations_result: SupabaseResult = await organization_repository.list_my_organizations()
	if not organizations_result.ok:
		_show_error(organizations_result.error_message)
		_show_workspace_setup_screen(organizations_result.error_message)
		return

	var loaded_organizations: Array[Organization] = _organizations_from_variant(organizations_result.data)
	state.set_organizations(loaded_organizations)

	if loaded_organizations.is_empty():
		_show_workspace_setup_screen()
	else:
		state.select_first_organization()
		_show_dashboard_screen()


func _show_auth_screen(status_message: String = "") -> void:
	var screen: AuthScreen = AuthScreen.new()
	screen.client_path = client_path
	screen.authenticated.connect(_on_auth_screen_authenticated)
	_set_screen(screen)
	if not status_message.strip_edges().is_empty():
		screen.set_status(status_message, true)


func _show_workspace_setup_screen(status_message: String = "") -> void:
	var screen: WorkspaceSetupScreen = WorkspaceSetupScreen.new()
	screen.organization_repository_path = organization_repository_path
	screen.set_profile(state.profile)
	screen.workspace_created.connect(_on_workspace_created)
	screen.sign_out_requested.connect(_on_sign_out_requested)
	_set_screen(screen)
	if not status_message.strip_edges().is_empty():
		screen.set_status(status_message, true)


func _show_dashboard_screen() -> void:
	var screen: DashboardShell = DashboardShell.new()
	screen.sign_out_requested.connect(_on_sign_out_requested)
	screen.refresh_requested.connect(_on_dashboard_refresh_requested)
	screen.set_state(state)
	_set_screen(screen)


func _show_boot_screen(message: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = BOOT_CARD_NAME
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_style(background_color, background_color, 0.0, 0.0, 0.0))

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(320.0, 140.0)
	card.add_theme_stylebox_override("panel", _make_style(card_color, border_color, 18.0, 1.0, 24.0))
	center.add_child(card)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var title: Label = Label.new()
	title.name = BOOT_LABEL_NAME
	title.text = message
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", text_color)
	content.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Please wait"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", muted_text_color)
	content.add_child(subtitle)

	var spinner: LoadingSpinner = LoadingSpinner.new()
	spinner.arc_segments = 62
	content.add_child(spinner)
	content.move_child(spinner, 1)

	_set_screen(panel)


func _set_screen(screen: Control) -> void:
	_ensure_ui()

	for child: Node in _host.get_children():
		_host.remove_child(child)
		child.queue_free()

	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.add_child(screen)


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

	_host = _root.get_node_or_null(_node_path(HOST_NAME)) as Control
	if _host == null:
		_host = Control.new()
		_host.name = HOST_NAME
		_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root.add_child(_host)


func _refresh_styles() -> void:
	if _root == null:
		return
	_root.add_theme_stylebox_override("panel", _make_style(background_color, background_color, 0.0, 0.0, 0.0))


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


func _organizations_from_variant(value: Variant) -> Array[Organization]:
	var output: Array[Organization] = []
	if value is Array:
		for item: Variant in value:
			if item is Organization:
				output.append(item)
	return output


func _on_auth_screen_authenticated() -> void:
	await _load_authenticated_area()


func _on_workspace_created(organization: Organization) -> void:
	if organization == null:
		return

	var updated_organizations: Array[Organization] = state.organizations.duplicate()
	updated_organizations.append(organization)
	state.set_organizations(updated_organizations)
	state.current_organization = organization
	_show_success("Workspace created.")
	_show_dashboard_screen()


func _on_dashboard_refresh_requested() -> void:
	await _load_authenticated_area()


func _on_sign_out_requested() -> void:
	var client: AppSupabaseClient = _get_client()
	if client != null:
		await client.sign_out()

	state.clear()
	_show_success("Signed out.")
	_show_auth_screen()


func _get_client() -> AppSupabaseClient:
	return get_node_or_null(client_path) as AppSupabaseClient


func _get_profile_repository() -> AppProfileRepository:
	return get_node_or_null(profile_repository_path) as AppProfileRepository


func _get_organization_repository() -> AppOrganizationRepository:
	return get_node_or_null(organization_repository_path) as AppOrganizationRepository


func _show_success(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_success(message)


func _show_warning(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_warning(message)


func _show_error(message: String) -> void:
	if has_node(^"/root/ToastManager"):
		ToastManager.show_error(message)


func _node_path(node_name: StringName) -> NodePath:
	return NodePath(String(node_name))
