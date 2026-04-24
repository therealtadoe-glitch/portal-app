class_name SupabaseSession
extends Resource

@export var access_token: String = ""
@export var refresh_token: String = ""
@export var token_type: String = "bearer"
@export var expires_in: int = 0
@export var expires_at_unix: int = 0
@export var user_id: String = ""
@export var email: String = ""

func is_authenticated(buffer_seconds: int = 30) -> bool:
	if access_token.strip_edges().is_empty():
		return false
	if expires_at_unix <= 0:
		return true
	return expires_at_unix > int(Time.get_unix_time_from_system()) + buffer_seconds

func should_refresh(buffer_seconds: int = 120) -> bool:
	if refresh_token.strip_edges().is_empty():
		return false
	if expires_at_unix <= 0:
		return false
	return expires_at_unix <= int(Time.get_unix_time_from_system()) + buffer_seconds

func clear() -> void:
	access_token = ""
	refresh_token = ""
	token_type = "bearer"
	expires_in = 0
	expires_at_unix = 0
	user_id = ""
	email = ""
	emit_changed()

func to_dictionary() -> Dictionary:
	return {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"token_type": token_type,
		"expires_in": expires_in,
		"expires_at": expires_at_unix,
		"user": {
			"id": user_id,
			"email": email
		}
	}

static func from_auth_response(payload: Dictionary) -> SupabaseSession:
	var session: SupabaseSession = SupabaseSession.new()
	session.access_token = String(payload.get("access_token", "")).strip_edges()
	session.refresh_token = String(payload.get("refresh_token", "")).strip_edges()
	session.token_type = String(payload.get("token_type", "bearer")).strip_edges()
	session.expires_in = int(payload.get("expires_in", 0))

	var expires_at_value: int = int(payload.get("expires_at", 0))
	if expires_at_value > 0:
		session.expires_at_unix = expires_at_value
	elif session.expires_in > 0:
		session.expires_at_unix = int(Time.get_unix_time_from_system()) + session.expires_in

	var user_value: Variant = payload.get("user", {})
	if user_value is Dictionary:
		var user: Dictionary = user_value
		session.user_id = String(user.get("id", "")).strip_edges()
		session.email = String(user.get("email", "")).strip_edges()

	return session

static func from_dictionary(payload: Dictionary) -> SupabaseSession:
	return SupabaseSession.from_auth_response(payload)
