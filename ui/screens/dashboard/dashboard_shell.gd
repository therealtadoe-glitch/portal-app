@tool
class_name DashboardShell
extends Control

signal sign_out_requested
signal refresh_requested

const NAV_NAME: StringName = &"NavigationShell"

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

var _nav: AppNavigationShell


func _ready() -> void:
	_ensure_ui()
	_rebuild_pages()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_styles()


func set_state(state: AppState) -> void:
	if state == null:
		_profile = null
		_current_organization = null
		_organizations.clear()
	else:
		_profile = state.profile
		_current_organization = state.current_organization
		_organizations = state.organizations.duplicate()

	_rebuild_pages()


func set_context(profile: Profile, current_organization: Organization, organizations: Array[Organization]) -> void:
	_profile = profile
	_current_organization = current_organization
	_organizations = organizations.duplicate()
	_rebuild_pages()


func _ensure_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(320.0, 560.0)

	_nav = get_node_or_null(_node_path(NAV_NAME)) as AppNavigationShell
	if _nav == null:
		_nav = AppNavigationShell.new()
		_nav.name = NAV_NAME
		_nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_nav)

	if not _nav.action_pressed.is_connected(_on_nav_action_pressed):
		_nav.action_pressed.connect(_on_nav_action_pressed)

	_refresh_styles()


func _rebuild_pages() -> void:
	if _nav == null:
		return

	var previous_tab_id: String = _nav.get_current_tab_id()
	if previous_tab_id.is_empty():
		previous_tab_id = "home"

	_nav.set_back_button_icon("res://assets/icons/interface-arrows-left--arrow-keyboard-left--Streamline-Core.svg")

	_nav.set_tabs([
		{
			"id": "home",
			"title": "Home",
			"icon_path": "res://assets/icons/interface-home-2--door-entrance-home-house-map-roof-round--Streamline-Core.svg",
			"show_label": false
		},
		{
			"id": "work",
			"title": "Work",
			"icon_path": "res://assets/icons/travel-airport-baggage--check-baggage-travel-adventure-luggage-bag-checked--Streamline-Core.svg",
			"show_label": false
		},
		{
			"id": "people",
			"title": "People",
			"icon_path": "res://assets/icons/interface-user-multiple--close-geometric-human-multiple-person-up-user--Streamline-Core.svg",
			"show_label": false
		},
		{
			"id": "more",
			"title": "More",
			"icon_path": "res://assets/icons/interface-setting-menu-1--button-parallel-horizontal-lines-menu-navigation-three-hamburger--Streamline-Core.svg",
			"show_label": false
			}
		])

	_nav.set_action_buttons([
		{
			"id": "refresh",
			"title": "Refresh",
			"icon_path": "res://assets/icons/interface-arrows-synchronize--arrows-loading-load-sync-synchronize-arrow-reload--Streamline-Core.svg",
			"show_label": false
		},
		{
			"id": "sign_out",
			"title": "Sign out",
			"icon_path": "res://assets/icons/interface-logout-circle--arrow-enter-right-logout-point-circle--Streamline-Core.svg",
			"show_label": false
		}
	])

	_nav.reset_navigation()

	_nav.set_tab_root_page(
		"home",
		"Home",
		_workspace_subtitle(),
		_build_home_page()
	)

	_nav.set_tab_root_page(
		"work",
		"Work",
		"Projects, tasks, and operations.",
		_build_work_page()
	)

	_nav.set_tab_root_page(
		"people",
		"People",
		"Employees, departments, and roles.",
		_build_people_page()
	)

	_nav.set_tab_root_page(
		"more",
		"More",
		"Account and workspace settings.",
		_build_more_page()
	)

	_nav.select_tab(previous_tab_id, false)
	_refresh_styles()


func _refresh_styles() -> void:
	if _nav == null:
		return

	_nav.background_color = background_color
	_nav.app_bar_color = Color("141925")
	_nav.bottom_bar_color = Color("141925")
	_nav.content_color = background_color
	_nav.elevated_color = elevated_color
	_nav.border_color = border_color
	_nav.accent_color = accent_color
	_nav.text_color = text_color
	_nav.muted_text_color = muted_text_color


func _build_home_page() -> Control:
	var page: ScrollContainer = _make_scroll_page()
	var content: VBoxContainer = _get_page_content(page)

	content.add_child(_make_header_block("Welcome back", _home_welcome_text()))

	content.add_child(_make_info_card("Workspace", _workspace_name(), _workspace_slug()))
	content.add_child(_make_info_card("Profile", _profile_name(), _profile_detail()))
	content.add_child(_make_info_card("Organizations", str(_organizations.size()), "Visible workspaces for this account."))

	content.add_child(_make_section_title("Quick actions"))

	content.add_child(_make_action_card(
		"Open tasks",
		"Review assignments, project work, and pending items.",
		"Go to Work",
		Callable(self, "_open_tasks")
	))

	content.add_child(_make_action_card(
		"Manage employees",
		"View team members, departments, and roles.",
		"Go to People",
		Callable(self, "_open_employees")
	))

	content.add_child(_make_action_card(
		"Workspace settings",
		"Review organization profile and account information.",
		"Open Settings",
		Callable(self, "_open_workspace_settings")
	))

	return page


func _build_work_page() -> Control:
	var page: ScrollContainer = _make_scroll_page()
	var content: VBoxContainer = _get_page_content(page)

	content.add_child(_make_header_block(
		"Work management",
		"Centralize projects, tasks, comments, time entries, and daily execution."
	))

	content.add_child(_make_action_card(
		"Projects",
		"Plan work by workspace, assign owners, and track project status.",
		"Open Projects",
		Callable(self, "_open_projects")
	))

	content.add_child(_make_action_card(
		"Tasks",
		"Track task status, priority, due dates, and assignments.",
		"Open Tasks",
		Callable(self, "_open_tasks")
	))

	content.add_child(_make_action_card(
		"Time entries",
		"Prepare employee time tracking and review flows.",
		"Open Time",
		Callable(self, "_open_time_entries")
	))

	return page


func _build_people_page() -> Control:
	var page: ScrollContainer = _make_scroll_page()
	var content: VBoxContainer = _get_page_content(page)

	content.add_child(_make_header_block(
		"People",
		"Manage employees, departments, roles, and internal access."
	))

	content.add_child(_make_action_card(
		"Employees",
		"Invite employees and manage member profiles.",
		"Open Employees",
		Callable(self, "_open_employees")
	))

	content.add_child(_make_action_card(
		"Departments",
		"Group employees by department and responsibility.",
		"Open Departments",
		Callable(self, "_open_departments")
	))

	content.add_child(_make_action_card(
		"Leave requests",
		"Review PTO, sick leave, and approval workflows.",
		"Open Leave",
		Callable(self, "_open_leave_requests")
	))

	return page


func _build_more_page() -> Control:
	var page: ScrollContainer = _make_scroll_page()
	var content: VBoxContainer = _get_page_content(page)

	content.add_child(_make_header_block(
		"Settings",
		"Account, workspace, and portal configuration."
	))

	content.add_child(_make_info_card("Signed in", _profile_name(), _profile_detail()))
	content.add_child(_make_info_card("Current workspace", _workspace_name(), _workspace_slug()))

	content.add_child(_make_action_card(
		"Refresh session data",
		"Reload profile and organization data from Supabase.",
		"Refresh",
		Callable(self, "_on_refresh_requested_from_page")
	))

	content.add_child(_make_danger_card(
		"Sign out",
		"End the current local session and return to auth.",
		"Sign out",
		Callable(self, "_on_sign_out_requested_from_page")
	))

	return page


func _build_detail_page(title: String, description: String, items: Array[String]) -> Control:
	var page: ScrollContainer = _make_scroll_page()
	var content: VBoxContainer = _get_page_content(page)

	content.add_child(_make_header_block(title, description))

	for item: String in items:
		content.add_child(_make_info_card(
			"Next",
			item,
			"This route is wired into the navigation stack and ready for the real data layer."
		))

	return page


func _open_projects() -> void:
	_open_detail(
		"work",
		"projects",
		"Projects",
		"Project boards will live here.",
		[
			"Create Project model and repository",
			"Fetch projects by organization",
			"Add project members",
			"Attach tasks to projects"
		]
	)


func _open_tasks() -> void:
	_open_detail(
		"work",
		"tasks",
		"Tasks",
		"Task management will live here.",
		[
			"Create Task model and repository",
			"Filter by assignee/status/priority",
			"Add task comments",
			"Support due dates and completion state"
		]
	)


func _open_time_entries() -> void:
	_open_detail(
		"work",
		"time_entries",
		"Time entries",
		"Employee time tracking will live here.",
		[
			"Clock in/out flow",
			"Manual time entries",
			"Manager review",
			"Weekly summaries"
		]
	)


func _open_employees() -> void:
	_open_detail(
		"people",
		"employees",
		"Employees",
		"Employee directory will live here.",
		[
			"List organization members",
			"Invite new users",
			"Change roles",
			"Deactivate access"
		]
	)


func _open_departments() -> void:
	_open_detail(
		"people",
		"departments",
		"Departments",
		"Department management will live here.",
		[
			"Create departments",
			"Assign department members",
			"Department managers",
			"Department-specific dashboards"
		]
	)


func _open_leave_requests() -> void:
	_open_detail(
		"people",
		"leave_requests",
		"Leave requests",
		"Leave and approval workflows will live here.",
		[
			"Submit leave request",
			"Approve or reject requests",
			"Track request status",
			"Show team leave calendar"
		]
	)


func _open_workspace_settings() -> void:
	_open_detail(
		"more",
		"workspace_settings",
		"Workspace settings",
		"Workspace configuration will live here.",
		[
			"Organization profile",
			"Roles and permissions",
			"Invite rules",
			"Audit log access"
		]
	)


func _open_detail(tab_id: String, route_id: String, title: String, description: String, items: Array[String]) -> void:
	if _nav == null:
		return

	_nav.select_tab(tab_id, true)
	_nav.push_page(
		route_id,
		title,
		_workspace_name(),
		_build_detail_page(title, description, items)
	)


func _make_scroll_page() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	return scroll


func _get_page_content(page: ScrollContainer) -> VBoxContainer:
	var margin: MarginContainer = page.get_node_or_null(^"Margin") as MarginContainer
	if margin == null:
		var fallback: VBoxContainer = VBoxContainer.new()
		return fallback

	var content: VBoxContainer = margin.get_node_or_null(^"Content") as VBoxContainer
	if content == null:
		var fallback: VBoxContainer = VBoxContainer.new()
		return fallback

	return content


func _make_header_block(title: String, subtitle: String) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 6)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", text_color)
	container.add_child(title_label)

	var subtitle_label: Label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", muted_text_color)
	container.add_child(subtitle_label)

	return container


func _make_section_title(title: String) -> Label:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", text_color)
	return label


func _make_info_card(title: String, value: String, detail: String) -> PanelContainer:
	var panel: PanelContainer = _make_card_panel()

	var content: VBoxContainer = _make_card_content()
	panel.add_child(content)

	content.add_child(_make_label(title, 13, muted_text_color))
	content.add_child(_make_label(value, 20, text_color))

	var detail_label: Label = _make_label(detail, 13, muted_text_color)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail_label)

	return panel


func _make_action_card(title: String, detail: String, button_text: String, callback: Callable) -> PanelContainer:
	var panel: PanelContainer = _make_card_panel()

	var content: VBoxContainer = _make_card_content()
	panel.add_child(content)

	content.add_child(_make_label(title, 18, text_color))

	var detail_label: Label = _make_label(detail, 13, muted_text_color)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail_label)

	var button: Button = _make_primary_button(button_text)
	if callback.is_valid():
		button.pressed.connect(callback)
	content.add_child(button)

	return panel


func _make_danger_card(title: String, detail: String, button_text: String, callback: Callable) -> PanelContainer:
	var panel: PanelContainer = _make_card_panel()

	var content: VBoxContainer = _make_card_content()
	panel.add_child(content)

	content.add_child(_make_label(title, 18, text_color))

	var detail_label: Label = _make_label(detail, 13, muted_text_color)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail_label)

	var button: Button = _make_secondary_button(button_text)
	if callback.is_valid():
		button.pressed.connect(callback)
	content.add_child(button)

	return panel


func _make_card_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 112.0)
	panel.add_theme_stylebox_override("panel", _make_style(surface_color, border_color, 18.0, 1.0, 18.0))
	return panel


func _make_card_content() -> VBoxContainer:
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	return content


func _make_label(label_text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_primary_button(button_text: String) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _make_style(accent_color, accent_color, 12.0, 0.0, 0.0))
	button.add_theme_stylebox_override("hover", _make_style(accent_color.lightened(0.08), accent_color.lightened(0.08), 12.0, 0.0, 0.0))
	button.add_theme_stylebox_override("pressed", _make_style(accent_color.darkened(0.12), accent_color.darkened(0.12), 12.0, 0.0, 0.0))
	button.add_theme_color_override("font_color", Color.WHITE)
	return button


func _make_secondary_button(button_text: String) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _make_style(elevated_color, border_color, 12.0, 1.0, 0.0))
	button.add_theme_stylebox_override("hover", _make_style(elevated_color.lightened(0.08), border_color.lightened(0.1), 12.0, 1.0, 0.0))
	button.add_theme_stylebox_override("pressed", _make_style(elevated_color.darkened(0.08), accent_color, 12.0, 1.0, 0.0))
	button.add_theme_color_override("font_color", text_color)
	return button


func _on_nav_action_pressed(action_id: String) -> void:
	match action_id:
		"refresh":
			refresh_requested.emit()
		"sign_out":
			sign_out_requested.emit()
		_:
			pass


func _on_refresh_requested_from_page() -> void:
	refresh_requested.emit()


func _on_sign_out_requested_from_page() -> void:
	sign_out_requested.emit()


func _home_welcome_text() -> String:
	if _current_organization != null:
		return "You are viewing %s. Use the bottom navigation to move between work, people, and settings." % _current_organization.name

	return "Use the bottom navigation to move between work, people, and settings."


func _workspace_name() -> String:
	if _current_organization != null and not _current_organization.name.strip_edges().is_empty():
		return _current_organization.name

	return "Workspace"


func _workspace_slug() -> String:
	if _current_organization != null and not _current_organization.slug.strip_edges().is_empty():
		return "Slug: %s" % _current_organization.slug

	return "No workspace slug"


func _workspace_subtitle() -> String:
	return "%s • %s" % [_profile_name(), _workspace_name()]


func _profile_name() -> String:
	if _profile != null and not _profile.display_name.strip_edges().is_empty():
		return _profile.display_name

	return "Employee"


func _profile_detail() -> String:
	if _profile != null and not _profile.email.strip_edges().is_empty():
		return _profile.email

	return "No email loaded"


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
