class_name AppSupabaseClient
extends Node

signal session_changed(session: SupabaseSession)
signal request_started(endpoint: String)
signal request_finished(endpoint: String, result: SupabaseResult)

const SETTING_SUPABASE_URL: StringName = &"application/supabase/url"
const SETTING_SUPABASE_PUBLISHABLE_KEY: StringName = &"application/supabase/publishable_key"
const DEFAULT_SESSION_PATH: String = "user://supabase_session.json"

@export var supabase_url: String = ""
@export var publishable_key: String = ""
@export var persist_session: bool = true
@export_range(2.0, 60.0, 1.0) var request_timeout_seconds: float = 20.0

var _session: SupabaseSession = SupabaseSession.new()
var _session_path: String = DEFAULT_SESSION_PATH


func _ready() -> void:
	_register_project_settings()
	configure_from_project_settings()

	if persist_session:
		_load_session_from_disk()


func configure_from_project_settings() -> void:
	var configured_url: String = String(ProjectSettings.get_setting(SETTING_SUPABASE_URL, "")).strip_edges()
	var configured_key: String = String(ProjectSettings.get_setting(SETTING_SUPABASE_PUBLISHABLE_KEY, "")).strip_edges()

	if not configured_url.is_empty():
		supabase_url = configured_url
	if not configured_key.is_empty():
		publishable_key = configured_key

	supabase_url = _normalize_base_url(supabase_url)
	publishable_key = publishable_key.strip_edges()


func configure(project_url: String, project_publishable_key: String) -> void:
	supabase_url = _normalize_base_url(project_url)
	publishable_key = project_publishable_key.strip_edges()


func is_configured() -> bool:
	return supabase_url.begins_with("https://") and not publishable_key.is_empty()


func get_session() -> SupabaseSession:
	return _session


func has_session() -> bool:
	return _session != null and _session.is_authenticated()


func get_user_id() -> String:
	if _session == null:
		return ""
	return _session.user_id


func get_user_email() -> String:
	if _session == null:
		return ""
	return _session.email


func sign_up(email: String, password: String, display_name: String = "") -> SupabaseResult:
	var clean_email: String = email.strip_edges().to_lower()
	var clean_display_name: String = display_name.strip_edges()

	var validation_error: String = _validate_email_password(clean_email, password)
	if not validation_error.is_empty():
		return SupabaseResult.failure(0, validation_error)

	var payload: Dictionary = {
		"email": clean_email,
		"password": password
	}

	if not clean_display_name.is_empty():
		payload["data"] = {"display_name": clean_display_name}

	var result: SupabaseResult = await _auth_request(HTTPClient.METHOD_POST, "/signup", payload, false)
	_capture_session_from_result(result)
	return result


func sign_in_with_password(email: String, password: String) -> SupabaseResult:
	var clean_email: String = email.strip_edges().to_lower()
	var validation_error: String = _validate_email_password(clean_email, password)
	if not validation_error.is_empty():
		return SupabaseResult.failure(0, validation_error)

	var payload: Dictionary = {
		"email": clean_email,
		"password": password
	}

	var result: SupabaseResult = await _auth_request(HTTPClient.METHOD_POST, "/token?grant_type=password", payload, false)
	_capture_session_from_result(result)
	return result


func refresh_session() -> SupabaseResult:
	if _session == null or _session.refresh_token.strip_edges().is_empty():
		return SupabaseResult.failure(401, "No refresh token is available. Sign in again.")

	var payload: Dictionary = {"refresh_token": _session.refresh_token}
	var result: SupabaseResult = await _auth_request(HTTPClient.METHOD_POST, "/token?grant_type=refresh_token", payload, false)
	_capture_session_from_result(result)
	return result


func sign_out() -> SupabaseResult:
	var result: SupabaseResult = await _auth_request(HTTPClient.METHOD_POST, "/logout", {}, true)
	_clear_session()
	return result


func select_rows(table: String, query: Dictionary = {}, require_auth: bool = true) -> SupabaseResult:
	var auth_result: SupabaseResult = await _ensure_ready_for_data_request(require_auth)
	if not auth_result.ok:
		return auth_result

	var endpoint: String = "/%s" % table.uri_encode()
	var query_string: String = _build_query_string(query)
	if not query_string.is_empty():
		endpoint += "?" + query_string

	return await _rest_request(HTTPClient.METHOD_GET, endpoint, null, require_auth)


func insert_row(table: String, values: Dictionary, require_auth: bool = true) -> SupabaseResult:
	var rows: Array[Dictionary] = [values]
	return await insert_rows(table, rows, require_auth)


func insert_rows(table: String, rows: Array[Dictionary], require_auth: bool = true) -> SupabaseResult:
	var auth_result: SupabaseResult = await _ensure_ready_for_data_request(require_auth)
	if not auth_result.ok:
		return auth_result

	var endpoint: String = "/%s" % table.uri_encode()
	var extra_headers: Array[String] = ["Prefer: return=representation"]
	return await _rest_request(HTTPClient.METHOD_POST, endpoint, rows, require_auth, extra_headers)


func update_rows(table: String, filters: Dictionary, values: Dictionary, require_auth: bool = true) -> SupabaseResult:
	var auth_result: SupabaseResult = await _ensure_ready_for_data_request(require_auth)
	if not auth_result.ok:
		return auth_result

	if filters.is_empty():
		return SupabaseResult.failure(0, "Refusing to update without filters.")

	var endpoint: String = "/%s?%s" % [table.uri_encode(), _build_query_string(filters)]
	var extra_headers: Array[String] = ["Prefer: return=representation"]
	return await _rest_request(HTTPClient.METHOD_PATCH, endpoint, values, require_auth, extra_headers)


func delete_rows(table: String, filters: Dictionary, require_auth: bool = true) -> SupabaseResult:
	var auth_result: SupabaseResult = await _ensure_ready_for_data_request(require_auth)
	if not auth_result.ok:
		return auth_result

	if filters.is_empty():
		return SupabaseResult.failure(0, "Refusing to delete without filters.")

	var endpoint: String = "/%s?%s" % [table.uri_encode(), _build_query_string(filters)]
	var extra_headers: Array[String] = ["Prefer: return=representation"]
	return await _rest_request(HTTPClient.METHOD_DELETE, endpoint, null, require_auth, extra_headers)


func call_rpc(function_name: String, payload: Dictionary = {}, require_auth: bool = true) -> SupabaseResult:
	var auth_result: SupabaseResult = await _ensure_ready_for_data_request(require_auth)
	if not auth_result.ok:
		return auth_result

	var endpoint: String = "/rpc/%s" % function_name.uri_encode()
	return await _rest_request(HTTPClient.METHOD_POST, endpoint, payload, require_auth)


func _ensure_ready_for_data_request(require_auth: bool) -> SupabaseResult:
	if not is_configured():
		return SupabaseResult.failure(0, "Supabase is not configured. Set Project Settings: application/supabase/url and application/supabase/publishable_key.")

	if not require_auth:
		return SupabaseResult.success(200)

	if _session == null or _session.access_token.strip_edges().is_empty():
		return SupabaseResult.failure(401, "Not authenticated.")

	if _session.should_refresh():
		var refresh_result: SupabaseResult = await refresh_session()
		if not refresh_result.ok:
			return refresh_result

	return SupabaseResult.success(200)


func _auth_request(method: int, endpoint: String, payload: Variant, include_access_token: bool) -> SupabaseResult:
	if not is_configured():
		return SupabaseResult.failure(0, "Supabase is not configured. Set Project Settings: application/supabase/url and application/supabase/publishable_key.")

	var url: String = "%s/auth/v1%s" % [supabase_url, endpoint]
	var headers: Array[String] = _build_headers(include_access_token)
	return await _request_json(method, url, headers, payload, endpoint)


func _rest_request(method: int, endpoint: String, payload: Variant, include_access_token: bool, extra_headers: Array[String] = []) -> SupabaseResult:
	var url: String = "%s/rest/v1%s" % [supabase_url, endpoint]
	var headers: Array[String] = _build_headers(include_access_token)
	for header: String in extra_headers:
		headers.append(header)
	return await _request_json(method, url, headers, payload, endpoint)


func _request_json(method: int, url: String, headers: Array[String], payload: Variant, endpoint: String) -> SupabaseResult:
	request_started.emit(endpoint)

	var body: String = ""
	if payload != null:
		body = JSON.stringify(payload)

	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = request_timeout_seconds
	add_child(request)

	var request_error: int = request.request(url, headers, method, body)
	if request_error != OK:
		request.queue_free()
		var start_failure: SupabaseResult = SupabaseResult.failure(0, "HTTPRequest failed to start: %s" % error_string(request_error))
		request_finished.emit(endpoint, start_failure)
		return start_failure

	var response: Array = await request.request_completed
	request.queue_free()

	var transport_result: int = int(response[0])
	var status_code: int = int(response[1])
	var body_bytes: PackedByteArray = response[3]
	var raw_body: String = body_bytes.get_string_from_utf8()

	if transport_result != HTTPRequest.RESULT_SUCCESS:
		var transport_failure: SupabaseResult = SupabaseResult.failure(status_code, "Network request failed: %s" % _http_request_result_name(transport_result), null, raw_body)
		request_finished.emit(endpoint, transport_failure)
		return transport_failure

	var parsed_data: Variant = null
	if not raw_body.strip_edges().is_empty():
		var parser: JSON = JSON.new()
		var parse_error: int = parser.parse(raw_body)
		if parse_error == OK:
			parsed_data = parser.data
		elif status_code >= 200 and status_code < 300:
			var parse_failure: SupabaseResult = SupabaseResult.failure(status_code, "Response was not valid JSON.", null, raw_body)
			request_finished.emit(endpoint, parse_failure)
			return parse_failure

	var result: SupabaseResult
	if status_code >= 200 and status_code < 300:
		result = SupabaseResult.success(status_code, parsed_data, raw_body)
	else:
		result = SupabaseResult.failure(status_code, _extract_error_message(status_code, parsed_data, raw_body), parsed_data, raw_body)

	request_finished.emit(endpoint, result)
	return result


func _build_headers(include_access_token: bool) -> Array[String]:
	var headers: Array[String] = [
		"apikey: %s" % publishable_key,
		"Accept: application/json",
		"Content-Type: application/json"
	]

	if include_access_token and _session != null and not _session.access_token.strip_edges().is_empty():
		headers.append("Authorization: Bearer %s" % _session.access_token)
	elif publishable_key.begins_with("eyJ"):
		headers.append("Authorization: Bearer %s" % publishable_key)

	return headers


func _build_query_string(query: Dictionary) -> String:
	var parts: Array[String] = []
	for key: Variant in query.keys():
		var encoded_key: String = String(key).uri_encode()
		var encoded_value: String = String(query[key]).uri_encode()
		parts.append("%s=%s" % [encoded_key, encoded_value])
	return "&".join(parts)


func _capture_session_from_result(result: SupabaseResult) -> void:
	if not result.ok:
		return
	if not (result.data is Dictionary):
		return

	var payload: Dictionary = result.data
	if not payload.has("access_token"):
		return

	_session = SupabaseSession.from_auth_response(payload)
	if persist_session:
		_save_session_to_disk()
	session_changed.emit(_session)


func _clear_session() -> void:
	if _session == null:
		_session = SupabaseSession.new()
	else:
		_session.clear()

	if FileAccess.file_exists(_session_path):
		var absolute_session_path: String = ProjectSettings.globalize_path(_session_path)
		var remove_error: int = DirAccess.remove_absolute(absolute_session_path)
		if remove_error != OK:
			push_warning("Could not remove Supabase session file: %s" % error_string(remove_error))

	session_changed.emit(_session)


func _save_session_to_disk() -> void:
	if _session == null:
		return

	var file: FileAccess = FileAccess.open(_session_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write Supabase session to %s" % _session_path)
		return

	file.store_string(JSON.stringify(_session.to_dictionary()))
	file.close()


func _load_session_from_disk() -> void:
	if not FileAccess.file_exists(_session_path):
		return

	var file: FileAccess = FileAccess.open(_session_path, FileAccess.READ)
	if file == null:
		return

	var raw_json: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(raw_json)
	if parse_error != OK or not (parser.data is Dictionary):
		push_warning("Saved Supabase session was invalid and could not be loaded.")
		return

	_session = SupabaseSession.from_dictionary(parser.data)
	session_changed.emit(_session)


func _validate_email_password(email: String, password: String) -> String:
	if email.is_empty() or not email.contains("@"):
		return "Enter a valid email address."
	if password.length() < 8:
		return "Password must be at least 8 characters."
	return ""


func _normalize_base_url(value: String) -> String:
	var normalized: String = value.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.trim_suffix("/")
	return normalized


func _extract_error_message(status_code: int, parsed_data: Variant, raw_body: String) -> String:
	if parsed_data is Dictionary:
		var payload: Dictionary = parsed_data
		for key: String in ["msg", "message", "error_description", "error", "hint", "details", "code"]:
			if payload.has(key):
				var value: String = String(payload[key]).strip_edges()
				if not value.is_empty():
					return value

	if not raw_body.strip_edges().is_empty():
		return raw_body.strip_edges()

	return "Supabase request failed with HTTP %d." % status_code


func _http_request_result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "BODY_DECOMPRESS_FAILED"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT:
			return "TIMEOUT"
		_:
			return "UNKNOWN_%d" % result


func _register_project_settings() -> void:
	_ensure_project_setting(SETTING_SUPABASE_URL, TYPE_STRING)
	_ensure_project_setting(SETTING_SUPABASE_PUBLISHABLE_KEY, TYPE_STRING)


func _ensure_project_setting(setting_name: StringName, setting_type: int) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, "")
		ProjectSettings.set_initial_value(setting_name, "")

	ProjectSettings.add_property_info({
		"name": String(setting_name),
		"type": setting_type,
		"hint": PROPERTY_HINT_NONE,
	})
