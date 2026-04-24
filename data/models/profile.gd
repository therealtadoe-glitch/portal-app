@tool
class_name Profile
extends Resource

@export var id: String = "":
	set(value):
		id = value.strip_edges()
		emit_changed()

@export var email: String = "":
	set(value):
		email = value.strip_edges()
		emit_changed()

@export var display_name: String = "Employee":
	set(value):
		var clean_value: String = value.strip_edges()
		display_name = "Employee" if clean_value.is_empty() else clean_value
		emit_changed()

@export var avatar_url: String = "":
	set(value):
		avatar_url = value.strip_edges()
		emit_changed()

@export var phone: String = "":
	set(value):
		phone = value.strip_edges()
		emit_changed()

@export var job_title: String = "":
	set(value):
		job_title = value.strip_edges()
		emit_changed()

@export var timezone: String = "UTC":
	set(value):
		var clean_value: String = value.strip_edges()
		timezone = "UTC" if clean_value.is_empty() else clean_value
		emit_changed()

@export var created_at: String = ""
@export var updated_at: String = ""


func is_valid() -> bool:
	return not id.is_empty() and not display_name.strip_edges().is_empty()


func to_update_dictionary() -> Dictionary:
	var payload: Dictionary = {
		"display_name": display_name.strip_edges(),
		"timezone": timezone.strip_edges()
	}

	var clean_avatar_url: String = avatar_url.strip_edges()
	if clean_avatar_url.is_empty():
		payload["avatar_url"] = null
	else:
		payload["avatar_url"] = clean_avatar_url

	var clean_phone: String = phone.strip_edges()
	if clean_phone.is_empty():
		payload["phone"] = null
	else:
		payload["phone"] = clean_phone

	var clean_job_title: String = job_title.strip_edges()
	if clean_job_title.is_empty():
		payload["job_title"] = null
	else:
		payload["job_title"] = clean_job_title

	return payload


static func from_dictionary(payload: Dictionary) -> Profile:
	var profile: Profile = Profile.new()
	profile.id = _read_string(payload, "id")
	profile.email = _read_string(payload, "email")
	profile.display_name = _read_string(payload, "display_name", "Employee")
	profile.avatar_url = _read_string(payload, "avatar_url")
	profile.phone = _read_string(payload, "phone")
	profile.job_title = _read_string(payload, "job_title")
	profile.timezone = _read_string(payload, "timezone", "UTC")
	profile.created_at = _read_string(payload, "created_at")
	profile.updated_at = _read_string(payload, "updated_at")
	return profile


static func _read_string(payload: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = payload.get(key, fallback)
	if value == null:
		return fallback

	return String(value).strip_edges()
